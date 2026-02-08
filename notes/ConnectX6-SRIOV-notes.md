# SR-IOV with a ConnectX-6

## Goal

Share a 100 Gbps dual-port network adapter with multiple VMs in a way that
allows the VMs to achieve near line-speed with active-passive fail-over between
ports (e.g. upstream switches) and allows for the VMs to be isolated to
different vxlans with ipsec tunnels providing transport encryption of most
intra-VM traffic.

## Important hardware/driver limitations

  - The NVidia documentation notes that ipsec encryption rates may be [less
    than line rate for 100 Gb/s connections](
    https://docs.nvidia.com/networking/display/mlnxofedv583070lts/ipsec+crypto+offload),
    but don't disclose the actual limit (directing the reader to contact their
    Nvidia representative. In my tests with tunneled vxlan ipsec3 traffic and
    9000 byte (overlay) mtu, the maximum ipsec encryption/decryption speed
    seems to be a very consistent *57.4 Gb/s* in each direction. While this
    isn't true line-rate encryption, it's probably close enough for my current
    use-case (and upgrading to a ConnectX-7 would fix this if needed).
  - It appears that ipsec offloading [is not currently supported over bonds
    (e.g. LCAP) except in an active-backup configuration](
    https://forums.developer.nvidia.com/t/bluefield-2-or-connectx-6-dx-crypto-enable-bonding-lacp-ipsec/341359
    ). This is probably good enough for my use case, since the active-backup
    configuration supports high-availability and I'm unlikely to need the
    additional bandwidth of an active-active configuration in the short term,
    but hopefully full LCAP support will eventually arrive.
  - RoCEv2 traffic is not routed by the linux kernel; thus failover between
    links requires bonding at the driver level.
  - There are quite a few firmware options on the ConnectX-6 Dx with often
    limited public documentation on what they do, but setting them incorrectly
    can lead to particular features failing or poor performance.

## Approaches to redundancy considered:

### L3 routing with ECMP across the two ports

In this scenario the routing software determines which links provide valid
paths for packets and (if both links are valid) a hash (e.g. of source and
destination ips and ports) is used to determine which link to send a pack
along.

Advantages:

  - Can use the full bandwidth of both links
  - Can use global routing information to make smart decisions about the best
    link to use (e.g. choose the port connected to the upstream switch with the
    shortest path to the destination)
  - Assuming L3 ECMP is also being used for connections between switches,
    allows a single unified approach for the entire route between two
    virtual machines, simplifying monitoring and debugging of the routes
    taken by packets.
  - Potential sub-second failover when a link or switch goes down.
  - Requires only basic L3 routing support on upstream switches.

Disadvantages:

  - Doesn't support RoCEv2 failover between links if routing is managed by
    the host (true by definition with a typical smart NIC like the
    ConnectX, but not neccesarily true with a DPU like a Bluefield card).
  - Because ipsec offload is attached to an individual port of the network
    card on the current ConnectX cards, you would potentially need four
    separate ipsec connections for each pair of hosts (one for each
    combination of incoming and outgoing ports) and more complicated
    routing rules to make sure that the traffic going over each physical
    connection was correctly mapped to the ips for that connection.
    Again, it appears that using DOCA flows on the Bluefield DPU (and
    possibly similar approaches on other DPUs) ipsec offloading can be
    configured in a way that is not tied to the port.
  - Requires multi-port eswitch support, which may have additional limitations
    (I've only found a small amount of documentation for using it with DDPK,
    and have not confirmed that it functions as expected with switchdev and
    tc flower).

My impression overall is using ECMP for redundancy is a great option for
cases like a typical contemporary cloud server when you don't have to
worry about local RoCEv2 connections or ipsec offloading or when using a
high-end DPU which can handle these two cases, but is not a great solution
otherwise.

### Bonded LCAP (802.3ad) with ESI-LAG on the upstream switches

For this approach, the host network card is configured as a standard linux
bond in an active-active configuration where the outgoing port for a packet is
chosen based on a hash of the header (e.g. of source and destination ports and
ips) with standards-defined protocol messages used to monitor the health of
each connection. While the protocol itself is written assuming that there is
a single machine on each side of the pair of links rather than two separate
switches, but using the (vendor neutral) ESI-LAG or a proprietary MLAG/MCLAG
implementation those two switches can be made to look like a single upstream
device for the purposes of a network bond.

Advantages:

  - Can use the full bandwidth of both links.
  - Natively supports RoCEv2 (via RoCEv2 LAG), using both links.

Disadvantages:

  - No ipsec offloading support (yet)
  - Requires higher-end offloading on upstream switches (ESI-LAG and/or MLAG).
  - Does not use global routing information to choose outbound port, so may
    make inefficient choices when the two paths are not equivalent (e.g. if a
    link failure occurs on the destination server).
  - Potential sub-second failover when a link or switch goes down.

My impression is that LCAP + ESI-LAG is a good option if ipsec is not needed,
but not an option if ipsec offload is needed (until driver support is added).

### Active-backup bond

For this approach, the upstream ports are bonded in an active-backup mode (so
if the link fails to one upstream switch it will automatically fail-over to the
other).

Advantages:

  - Full RoCEv2 support
  - Full ipsec offloading support
  - Minimal requirements from upstream switches
  - Requires only basic L3 routing support on upstream switches.

Disadvantages:

  - Only utilizes one of the two links at a time (which may not be the closest
    link to the destination).
  - Failing over to the backup link requires establishing a new BGP session,
    which will often take more than 1 second even with aggressive tuning.
    A multi-hop "warm" spare setup may be possible to reduce this time.

My overall impression is that this is a practical approach that will support
RoCEv2 and ipsec offloads while still coming within a factor of 2 of the
fastest approaches.


## Materials and Methods

### Hardware

Two machines each with Epyc 4545P processors and ConnectX-6 Dx cards
(MCX623106AC) in x8 PCIe slots with 100 Gb/s optics (note that the x8 PCIe 4
connection will limit maximum bandwidth to ~100 Gb/s). You can find [ the
firmware settings used for the ConnectX-6 Dx cards here](
./ConnectX6-ipsec-bond-example.mstconfig.query ), as reported by
`sudo mstconfig --dev 03:00.0 query`.

### Software stack used

From [prior experiments with the Mellanox ConnectX-5](ConnectX5-SRIOV-notes.md)
the switchdev/tc software stack seemed to provide a good balance of offload
performance, features, and low idle CPU usage, so it was used for this set of
experiments.

### Network performance measurements

The throughput was measured with iperf3 with different MTU
and number of threads, recorded below as iperf3 <MTU>/<THREADS>. Because there
was significant variability (perhaps based on cpu core assignment?) the command
was run first with a single warm-up run, and then with 10 runs. As the sent and
received traffic were relatively symmetric, this then generated 20 average
transfer speeds, of which the mean and sample deviation are reported.:

```
iperf3 --parallel 2 --bidi --client 192.168.90.3
```

The latency for each approach was measured using a flood ping, with one warm up
run (to initialize the flows) followed by a second run, with the mean and
population standard deviation reported from the results of the second run.

```
ping -fc 10000 192.168.90.3
```

[The script used can be found here](../scipts/iperfstats.py).

To create the complete offloaded configuration labeled "VM-VM bond, ovs/tc,
VXLAN, NIC IPsec", the machines were configured as described below. For the
"VM-VM bond, ovs/tc, VXLAN" test the configuration was as described but the ip
xfrm policies and states were flushed at the end (removing ipsec). The "VM-VM
bond, ovs/tc, VXLAN" state was created by then disabling OVS offloads by
running `sudo ovs-vsctl set Open_vSwitch . other_config:hw-offload=false &&
sudo systemctl restart openvswitch-switch.service`. The "host-to-host, 1-port,
legacy" results were obtained after a fresh boot with manual assignment of an
ip address and MTU to one of the PFs on the NIC using the standard iproute2
tools (e.g. `ip addr ...`). The "host-to-host, 1-port, CPU IPsec, legacy"
results were then obtained by adding xfrm state and policy rules similar to the
ones below but with the packet offload lines removed.

The improved ipsec performance with an MTU of 3992 was discovered by a chance
setting of the MTU near this value and then manual tuning of the MTU. I suspect
it is the packet size that will fit into a single 4096 byte memory page (and
thus a single DMA request) after adding the vxlan and ipsec headers, but I have
not confirmed this yet with a packet sniffer. Under optimal conditions (e.g.
with a VF in a namespace on the host) I have seen rates of 65.5 Gb/s with this
setting. All results are shown with an underlay MTU of 9216, an overlay MTU of
9000, and the indicated route MTU.

## Results

| Approach                                        | iperf3<br>1500/2<br>(Gb/s) | iperf3<br>3992/2<br>(Gb/s)    | iperf3<br>9000/2<br>(Gb/s) | iperf3<br>9000/6<br>(Gb/s) | ping rtt<br>(μs) |
| ----------------------------------------------- | -------------------------- | ----------------------------- | -------------------------- | -------------------------- | ---------------- |
| host-to-host, 1-port,<br>legacy                 |      67.3  ± 2.7           |            89.  ± 4.          |       94.  ± 3.            |       88.   ± 3.           |     31 ± 3       |
| host-to-host, 1-port,<br>CPU IPsec, legacy      |       3.97 ± 0.11          |             8.4 ± 0.4         |       15.0 ± 0.3           |       11.6  ± 1.1          |     30 ± 1       |
| VM-VM bond, ovs,<br>VXLAN                       |       4.39 ± 0.19          |            10.3 ± 0.9         |       13.2 ± 1.1           |       11.9  ± 1.0          |     77 ± 6       |
| VM-VM bond, ovs/tc,<br>VXLAN                    |      40.   ± 5.            |            81.  ± 6.          |       79.  ± 7.            |       97.0  ± 0.8          |     31 ± 3       |
| VM-VM bond, ovs/tc,<br>VXLAN, NIC IPsec         |      40.   ± 6.            |            62.2 ± 2.2         |       57.1 ± 0.4           |       57.35 ± 0.04         |     33 ± 3       |

Additions:

With an underlay MTU 0f 1600 and an overlay MTU of 1500 and 6 streams, the full
ovs/tc + VXLAN + NIC IPsec is able to reach 75 ± 9 Gb/s; further turning may be
possible (perhaps by enabling things like ECN).

## Conclusions

 - Network performance drops dramatically (5x - 14x) when OVS or ipsec are used
   without hardware offloading.
 - With offloading, an OVS vxlan adds a small (0-20%) performance penalty
 - With offloading, ipsec adds a moderate (30-40%) performance penalty

## Common steps

### Step 0 (once per OS-install) install prerequisites

Install a few common debian packages used in this example

```
sudo apt install -y mstflint wget qemu-system-x86 \
    openvswitch-switch openvswitch-vtep \
    openvswitch-ipsec strongswan-starter
```

Enable openvswitch hardware offloads

```
sudo ovs-vsctl --no-wait set Open_vSwitch . other_config:hw-offload=true
```

You will also need to locate and download the [latest versions of the DOCA-OFED
drivers](https://developer.nvidia.com/doca-downloads).

```
wget https://www.mellanox.com/downloads/DOCA/DOCA_v3.2.1/host/doca-host_3.2.1-044000-25.10-debian13_amd64.deb
```

Unfortunately the DOCA 3.2.1 drivers seem to have compatibility problems with
newer kernel versions (6.12.48 works, 6.12.57 does not), so you may have to
pin an older kernel version using something like the following:

```
cat << EOF | sudo tee /etc/apt/preferences.d/pin-kernel.pref
Package: linux-image-amd64
Pin: version 6.12.48-1
Pin-Priority: 990

Package: linux-headers-amd64
Pin: version 6.12.48-1
Pin-Priority: 990
EOF
```

You may also need to manually roll back the kernel packages to this version
using a tool such as aptitude.

With a compatible kernel version, you can then install the DOCA-OFED drivers,
e.g.

```
sudo dpkg -i doca-host_3.2.1-044000-25.10-debian13_amd64.deb
sudo apt-get update
sudo apt-get -y install doca-ofed
```


### Step 1 (once per NIC) update firmware and max SR-IOV devices

Find the network card pcie addresses:

```
lspci | grep ellanox
```

Find the exact model number and currently installed firmware

```
sudo mstflint --device 03:00.0 query
```

Find and download the
[latest matching firmware](https://network.nvidia.com/support/firmware/connectx6dx/)

```
wget https://www.mellanox.com/downloads/firmware/fw-ConnectX6Dx-rel-22_47_1088-MCX623106AC-CDA_Ax-UEFI-14.40.10-FlexBoot-3.8.201.signed.bin.zip
unzip fw-ConnectX6Dx-rel-22_47_1088-MCX623106AC-CDA_Ax-UEFI-14.40.10-FlexBoot-3.8.201.signed.bin.zip
```

Install the firmware and reboot the card with the new firmware

```
sudo mstflint --dev 03:00.0 -i fw-ConnectX6Dx-rel-22_47_1088-MCX623106AC-CDA_Ax-UEFI-14.40.10-FlexBoot-3.8.201.signed.bin burn
sudo mstfwreset --dev 03:00.0 reset
```

Confirm ipsec acceleration is available:

Example of a working card:
```
$ sudo ethtool -k enp3s0f0np0 | grep esp
tx-esp-segmentation: on
esp-hw-offload: on [fixed]
esp-tx-csum-hw-offload: on [fixed]
$ sudo dmesg | grep -i ipsec
[   10.065419] mlx5_core 0000:03:00.0: mlx5e: IPSec ESP acceleration enabled
[   10.857570] mlx5_core 0000:03:00.1: mlx5e: IPSec ESP acceleration enabled
```

Example of a non-working card:

```
$ sudo ethtool -k enp3s0f0np0 | grep esp
tx-esp-segmentation: off [fixed]
esp-hw-offload: off [fixed]
esp-tx-csum-hw-offload: off [fixed]
$ sudo dmesg | grep -i ipsec
```

Enable SR-IOV and set the maximum number of SR-IOV virtual functions (VFs;
conceptually virtual network cards to can pass the the VMs) allowed by the
firmware. This apparently sets the amount of PCIe BAR memory requested by the
card, and setting it too high will cause some servers to crash on boot. I think
the card supports up to 127, but I've only tried 16 so far.

```
sudo mstconfig --dev 03:00.0 set SRIOV_EN=1 NUM_OF_VFS=16
```

Some features, including multi-port eswitch and ip-sec over an active-passive
bond, may require the following setting (cargo-culting from the
[DDPK multiport eswitch documentation-](
https://doc.dpdk.org/guides/nics/mlx5.html#multiport-e-switch) ). I haven't
found any documentation that this must be set to support ipsec offloading
over a bond, but I have been unable to get this offloading to work without
this setting.

```
sudo mstconfig --dev 03:00.0 set LAG_RESOURCE_ALLOCATION=1
```

Reboot the system to set up the new PCIe BAR, etc. for SR-IOV

```
sudo reboot
```

### Step 2: setup Switchdev and an active-backup bond
We first declare some variables to make it easier to keep track of
(potentially) machine-specific details such as ip addresses and the bus address
of the network card:

```
PF0=enp3s0f0np0 # netdev name of the first port (physical function = PF) on the NIC
PF1=enp3s0f1np1 # netdev name of the second port on the NIC
VF=enp3s0f0v0   # netdev name of the virtual function (VF) we will use for the VM
REPRESENTOR=enp3s0f0r0 # representor interface corresponding to the VF above
PF0_BUSID=pci/0000:03:00.0 # Bus ID of PF0
PF1_BUSID=pci/0000:03:00.1 # Bus ID of PF1
LOCAL_BOND_IP=192.168.70.2 # the underlay address of the NIC's bond
LOCAL_VTEP_IP=192.168.80.2 # the underlay address that will be used for the vxlan
LOCAL_VF_IP=192.168.90.2 # the overlay address that will be used for the VM
REMOTE_BOND_IP=192.168.70.3 # the underlay address of the remote machine
REMOTE_VTEP_IP=192.168.80.3 # the underlay address of the remote vxlan
REMOTE_VF_IP=192.168.90.3 # the overlay address of the remote VM
```

Next we make sure we're starting from a clean slate by flushing any existing
ipsec policies or state associations, deleting any existing bond0 interface,
and setting the network ports to the "down" state.

```
sudo ip xfrm state flush
sudo ip xfrm policy flush
sudo ip link delete bond0 || true
sudo ip link set ${PF0} down
sudo ip link set ${PF1} down
```

Ipsec offloading requires that driver use the firmware to create hardware
rules on the NIC (known as [device managed flow steering, or DMFS](
https://docs.kernel.org/next/networking/device_drivers/ethernet/mellanox/mlx5/devlink.html#flow-steering-mode-device-flow-steering-mode
) ) and that the device be in switchdev mode. Before we can change these,
however, we need to make sure that no VFs are bound by the driver.
A simple way to do this is to set the number of VFs to 0 while we are making
these changes.

```
echo '0' | sudo tee -a /sys/class/net/${PF0}/device/sriov_numvfs
echo '0' | sudo tee -a /sys/class/net/${PF1}/device/sriov_numvfs
```

We can then make sure the NIC is in legacy mode, set these flow steering mode,
and switch it to switchdev mode.

```
sudo devlink dev eswitch set ${PF0_BUSID} mode legacy
sudo devlink dev eswitch set ${PF1_BUSID} mode legacy
sudo devlink dev param set ${PF0_BUSID} name flow_steering_mode value dmfs cmode runtime
sudo devlink dev param set ${PF1_BUSID} name flow_steering_mode value dmfs cmode runtime
sudo devlink dev eswitch set ${PF0_BUSID} mode switchdev
sudo devlink dev eswitch set ${PF1_BUSID} mode switchdev
```

Now we can re-create some VFs (two per PF in this example)

```
echo '2' | sudo tee -a /sys/class/net/${PF0}/device/sriov_numvfs
echo '2' | sudo tee -a /sys/class/net/${PF1}/device/sriov_numvfs
```

Next we create the bond interface and add the two PFs to the bond

```
sudo ip link add dev bond0 type bond mode active-backup miimon 100
sudo ip link set dev ${PF0} master bond0
sudo ip link set dev ${PF1} master bond0
```

We also make sure that the ipsec offloads are enabled for the bond

```
sudo ethtool --offload bond0 esp-hw-offload on
sudo ethtool --offload bond0 esp-tx-csum-hw-offload on
```

Next, we assign an ip address to the bond and set it and its slave interfaces
to the "up" state.

```
sudo ip addr replace ${LOCAL_BOND_IP}/24 dev bond0
sudo ip link set dev ${PF0} mtu 9216 up
sudo ip link set dev ${PF1} mtu 9216 up
sudo ip link set dev bond0 mtu 9216 up
```

### Step 3a: ipsec using low-level ip xfrm interface and pre-shared key

An IPsec connection requires establishing shared secret keys between the two
machines (typically with a protocol like IKEv2 that can use public keys and
certificates, similar to TLS) and also rotation of those shared keys over time.
Those shared secret keys are then used to encrypt network packets sent between
the two machines. The linux kernel [only handles the low level encryption of
packets](https://docs.kernel.org/networking/xfrm/xfrm_device.html)
 with the secret keys and depends on a user level program (e.g.
strongswan) to manage things like the initial key exchange and key rotation.

To simplify this experiment, we'll use the low-level linux xfrm commands
directly to set up an ipsec connection.  These intended for use by programs
such as stronswan rather than typical users, so they are a bit ugly and
verbose. The ipsec connection consists of two unidirectional connections, one
for packets going 'out' to the remote machine and one for packets arriving 'in'
from the remote machine. For each connection we first need to create an xfrm
state, which defines things like the encryption key and algorithm used and
stores things like packet sequence numbers:

```
sudo ip xfrm state add \
    src ${LOCAL_VTEP_IP}/24 \
    dst ${REMOTE_VTEP_IP}/24 \
    proto esp \
    spi ${SPI_OUT} \
    reqid ${REQID_OUT} \
    mode transport \
    aead 'rfc4106(gcm(aes))' ${PSK_OUT} 128 \
    offload packet dev ${PF0} dir out \
    sel \
        src ${LOCAL_VTEP_IP} \
        dst ${REMOTE_VTEP_IP} \
        flag esn \
        # replay-window 64
sudo ip xfrm state add \
    src ${REMOTE_VTEP_IP}/24 \
    dst ${LOCAL_VTEP_IP}/24 \
    proto esp \
    spi ${SPI_IN} \
    reqid ${REQID_IN} \
    mode transport \
    aead 'rfc4106(gcm(aes))' ${PSK_IN} 128 \
    offload packet dev ${PF0} dir in \
    sel \
        src ${REMOTE_VTEP_IP} \
        dst ${LOCAL_VTEP_IP} \
        flag esn \
        replay-window 64
```

For each connection, we also need to define an xfrm policy which will be
applied to incoming and outgoing packets to decide if they need to be processed
by the ipsec code, and if so which xfrm state to use for that packet.

```
sudo ip xfrm policy add \
    src ${LOCAL_VTEP_IP} \
    dst ${REMOTE_VTEP_IP} \
    offload packet dev ${PF0} \
    dir out \
    tmpl \
    src ${LOCAL_VTEP_IP}/24 \
    dst ${REMOTE_VTEP_IP}/24 \
    proto esp \
        reqid ${REQID_OUT} \
        mode transport \
        priority 12
sudo ip xfrm policy add \
    src ${REMOTE_VTEP_IP} \
    dst ${LOCAL_VTEP_IP} \
    offload packet dev ${PF0} \
    dir in \
    tmpl \
    src ${REMOTE_VTEP_IP}/24 \
    dst ${LOCAL_VTEP_IP}/24 \
    proto esp \
        reqid ${REQID_IN} \
        mode transport \
        priority 12
```

For each of these, note the `offload packet ...` line of parameters - these
enable offloading of the entire encapsulation and encryption to the network
adapter, and also indicate which network adapter will be used for offloading
(which must match the one the given packets are received or sent on).

### Step 5: vxlan setup

The vxlan needs an interface and ip address on the underlay network to send and
receive the tunneled packets, known as a virtual tunnel end point or VTEP.
While we could use the the bond itself and its current underlay ip address,
it's often useful to create a new ip address for each VTEP (e.g. so that you
can apply different packet filtering or ipsec policies) and assign that address
to the loop back interface, allowing packets to reach it from multiple
interfaces.

```
sudo ip addr replace ${LOCAL_VTEP_IP}/32 dev lo
```

We then will also need to provide a route to reach the VTEP address on the
remote machine, which we will add manually for this example (but would likely
be provided by something like BGP in a production setting).

```
sudo ip route replace to ${REMOTE_VTEP_IP}/32 nexthop via ${REMOTE_BOND_IP}
```

Next, we set up the representor for the VF. Note that we are choosing the
overlay MTU so that the packet plus the ipsec and vxlan headers will just
fit into a 4k memory page (since this seems to help ipsec offloading
performance).

```
sudo ip link set ${REPRESENTOR} mtu $(( 4096 - 110 )) up
```

We then create an OVS bridge (after deleting the old one if it was there) and
add the representor to the bridge.

```
sudo ovs-vsctl del-br br-ovs || true
sudo ovs-vsctl add-br br-ovs
sudo ovs-vsctl add-port br-ovs ${REPRESENTOR}
```

We also create and add a vxlan interface to the bridge.

```
sudo ovs-vsctl add-port br-ovs vxlan1 \
    -- set interface vxlan1 type=vxlan \
    options:local_ip=${LOCAL_VTEP_IP} \
    options:remote_ip=${REMOTE_VTEP_IP} \
    options:key=1024 \
    options:dst_port=4789

```

### Step 6: VM setup

For setting up the VM, we follow the same general approach used
in the [previous ConnectX-5 experiments](
ConnectX5-SRIOV-notes.md ), with the following largely copied from these prior
notes.

To start, we need to bind the VF to the vfio driver on the host. First, load
the vfio driver and let it know that it should claim this type of device:

```
sudo modprobe vfio-pci
echo $(cat /sys/bus/pci/devices/0000\:03\:00.2/{vendor,device}) \
    | sudo tee -a /sys/bus/pci/drivers/vfio-pci/new_id
```

Unbind the VF from the mlx5 driver and rebind it to the vfio driver

```
echo "0000:03:00.2" | sudo tee /sys/bus/pci/drivers/mlx5_core/unbind
echo "0000:03:00.2" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind
```

Run qemu, using pci-passthrough for a VF. In this example, you can log in to
the VM with root with a blank password.

```
if ! [ -f debian-13-nocloud-amd64-20250814-2204.qcow2 ]; then
    wget https://cloud.debian.org/images/cloud/trixie/20250814-2204/debian-13-nocloud-amd64-20250814-2204.qcow2
fi
sudo qemu-system-x86_64 -accel kvm -nographic -m 8G -cpu host -smp 16 \
    -drive file=debian-13-nocloud-amd64-20250814-2204.qcow2 \
    -device vfio-pci,host=0000:03:00.2
```

In the VM, you can just configure this NIC as usual

```
sudo ip addr add dev ens4 192.168.90.2/24
sudo ip link set dev ens4 up mtu $(( 4096 - 110 ))
```


## Confirming ipsec is being used

One quick check that the traffic is encrypted is by looking at the number of
ipsec bytes and packets with either `ethtool` on the host machine:

```
sudo ethtool -S enp3s0f0np0 | grep ipsec
```

or with `ip xfrm state`:

```
sudo ip -s xfrm state
```

You should see both numbers rise rapidly when iperf3 is being used in
appropriate proportion to the network traffic.

### Other useful articles

  - [Linux XFRM Reference Guide for IPsec](
    https://pchaigno.github.io/xfrm/2024/10/30/linux-xfrm-ipsec-reference-guide.html)
  - [Nftables - Netfilter and VPN/IPsec packet flow](
        https://thermalcircle.de/doku.php?id=blog:linux:nftables_ipsec_packet_flow)
  - [Figuring out how ipsec transforms work in Linux](
        https://blog.hansenpartnership.com/figuring-out-how-ipsec-transforms-work-in-linux/)
