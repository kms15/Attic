# SR-IOV with a ConnectX-5

## Goal

Share a 100 Gbps dual-port network adapter with multiple VMs in a way that
allows the VMs to achieve near line-speed with active-passive fail-over between
ports (e.g. upstream switches) and allows for the VMs to be isolated to
different network subsets (e.g. a trusted storage backend network, a public
network, etc). The hope is to support NVME-backed ceph nodes that can provide
fast streaming data to GPU nodes doing ML training while still providing a
multi-tenent-like setup to keep my work, my household/iot/family networks, and
work with friends and collaborators isolated from each other.

## Materials and Methods

### Hardware

Two machines each with Epyc 4545P processors and ConnectX-5 Ex cards in x8
PCIe slots.

### Software stacks tried

 - Legacy linux kernel stack (i.e. not using switchdev) with SR-IOV and VLAN
   tunnels using the mlx5 driver offloads available for LAG and VLAN tagging.
 - OVS and DPDK with SR-IOV and VXLAN tunnels using the mlx5 driver offloads.
 - OVS and switchdev/tc with SR-IOV and VXLAN tunnels using the mlx5 offloads.

### Network performance measurements

The throughput for each approach was measured with iperf3 with different MTU
and number of threads, recorded below as iperf3/<MTU>/<THREADS>. Because there
was significant variability (perhaps based on cpu core assignment?) the command
was run 3 times and the median of the 6 values recorded. Here is an example
command with 2 threads:

```
iperf3 --parallel 2 --bidi --client 192.168.10.1
```

The latency for each approach was measured using a flood ping, with one warm up
run (to initialize the flows) followed by three more runs, with the median
recorded.

```
ping -fc 10000 192.168.10.1
```

## Results

| Approach         | iperf3/1500/2 (Gb/s) | iperf3/9000/2 (Gb/s) | iperf3/9000/6 (Gb/s) | ping mean (us) | ping mdev (us) |
| ---------------- | -------------------- | -------------------- | -------------------- | -------------- | -------------- |
| legacy + VLAN    |        70            |           82         |            95        |         30     |       7        |
| ovs/dpdk + VXLAN |        61            |           85         |            96        |         32     |       3        |
| ovs/tc + VXLAN   |        83            |           86         |            96        |         28     |       5        |


## Conclusions

- The legacy software stack appears to perform relatively well with SR-IOV and
  VLAN offloading and worked well with the stock linux kernel driver
  in debian 13. Unfortunately appears to have more limited support for
  offloads beyond this (e.g. VXLAN, traffic filtering, etc) and I wasn't able
  to get the VF-LAG offloading to work, meaning each virtual machine needed
  to configure its own bond from two separate VFs.
- OVS+DPDK performed relatively well (and probably could perform better with
  tuning) and provides a lot of further features, including good openstack
  integration. It does require one core running at full speed all of the time
  doing polling (which is not ideal environmentally) and I wasn't able to get
  it working without installing the proprietary NVIDIA driver.
- OVS and switchdev/tc performed quite well, and provides a relatively rich
  feature set. I wasn't able to get it running without installing the
  proprietary NVIDIA driver, however.

## Common steps

### Step 0 (once per OS-install) install prerequisites

```
sudo apt install mstflint wget qemu-system-x86
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
[latest matching firmware](https://network.nvidia.com/support/firmware/connectx5en/)

```
wget https://www.mellanox.com/downloads/firmware/fw-ConnectX5-rel-16_35_4554-MCX516A-CDA_Ax_Bx-UEFI-14.29.15-FlexBoot-3.6.902.bin.zip
unzip fw-ConnectX5-rel-16_35_4554-MCX516A-CDA_Ax_Bx-UEFI-14.29.15-FlexBoot-3.6.902.bin.zip
```

Install the firmware and reboot the card with the new firmware

```
sudo mstflint --dev 03:00.0 -i fw-ConnectX5-rel-16_35_4554-MCX516A-CDA_Ax_Bx-UEFI-14.29.15-FlexBoot-3.6.902.bin burn
sudo mstfwreset --dev 03:00.0 reset
```

Enable SR-IOV and set the maximum number of SR-IOV virtual functions (VFs;
conceptually virtual network cards to can pass the the VMs) allowed by the
firmware. This apparently sets the amount of PCIe BAR memory requested by the
card, and setting it too high will cause some servers to crash on boot. I think
the card supports up to 127, but I've only tried 16 so far.

```
sudo mstconfig --dev 03:00.0 set SRIOV_EN=1 NUM_OF_VFS=16
```

Reboot the system to set up the new PCIe BAR, etc. for SR-IOV

```
sudo reboot
```

## Approach 1 using iproute2 functionality

### Step 2A1 set up host machine networking (on each boot of the host machine)

Set each of the physical functions (PFs, corresponding to the two ports on the
network card) to have 2 virtual functions (works fine with 16 VFs and probably
higher).

```
echo '2' | sudo tee -a /sys/class/net/enp3s0f1np1/device/sriov_numvfs
echo '2' | sudo tee -a /sys/class/net/enp3s0f0np0/device/sriov_numvfs
```

Set VF 1 of each device to be on vlan 40 (i.e. add a vlan 40 tag to all outgoing
packets on this vf and accept only packets with a vlan 40 tag, stripping off the
vlan tag before presenting it to the vm).


```
sudo ip link set dev enp3s0f0np0 vf 1 vlan 40
sudo ip link set dev enp3s0f1np1 vf 1 vlan 40
```

The VFs that will be passed to the virtual machine need to be bound to the
vfio-pci driver. First we load the vfio-pci module and inform it that it can
bind to this type of device:

```
sudo modprobe vfio-pci
echo $(cat /sys/bus/pci/devices/0000\:03\:00.3/{vendor,device}) \
    | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id
```

Now we unbind the ports from the mlx5_core driver and rebind them to the
vfio-pci driver.

```
echo "0000:03:00.3" | sudo tee /sys/bus/pci/drivers/mlx5_core/unbind
echo "0000:03:02.3" | sudo tee /sys/bus/pci/drivers/mlx5_core/unbind
echo "0000:03:00.3" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind
echo "0000:03:02.3" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind
```
Set the MTU on the PFs to allow for jumbo frames (in this case 9000
bytes plus some extra space for L2 headers and things like vxlan or geneve)

```
sudo ip link set mtu 9080 dev enp3s0f0np0
sudo ip link set mtu 9080 dev enp3s0f1np1
```

Run qemu, using pci-passthrough for one VF from each PF (physical function, i.e.
port). In this example, you can log in to the VM with root with a blank
password.

```
if ! [ -f debian-13-nocloud-amd64-20250814-2204.qcow2 ]; then
    wget https://cloud.debian.org/images/cloud/trixie/20250814-2204/debian-13-nocloud-amd64-20250814-2204.qcow2
fi
sudo qemu-system-x86_64 -accel kvm -nographic -m 8G -cpu host -smp 16 \
    -drive file=debian-13-nocloud-amd64-20250814-2204.qcow2 \
    -device vfio-pci,host=0000:03:00.3  \
    -device vfio-pci,host=0000:03:02.3
```

### Step 2A2 set up the bond on the vm (on each boot of the VM)

Create the bonding interface

```
sudo ip link add dev bond0 type bond mode active-backup miimon 100
```

Set the bond interface and its future child interfaces to be down

```
ip link set dev ens4 down
ip link set dev ens5 down
ip link set dev bond0 down
```

Link the child interfaces to the bond

```
ip link set ens4 master bond0
ip link set ens5 master bond0
```

Set the bond and its child interfaces to be up again

```
ip link set dev ens4 up mtu 9000
ip link set dev ens5 up mtu 9000
ip link set dev bond0 up mtu 9000
```

Add an ip address and subnet to the bond

```
ip addr add 192.168.10.2/24 dev bond0
```

## Approach 2 using DPDK and OVS


### Step 2B1 (once per OS-install) install prerequisites

TODO: this did not result in a working VF LAG setup with the stock debian
packages described in this subsection, and only seemed to work when I installed
the proprietary NVIDIA packages (described in approach 3).

We will need DPDK and the DPDK-enabled version of openvswitch:

```
sudo apt install openvswitch-switch-dpdk dpdk
```

By default the non-DPDK open-vswitch daemon is used, so we need to switch to
the DPDK version:

```
sudo update-alternatives --set ovs-vswitchd \
    /usr/lib/openvswitch-switch-dpdk/ovs-vswitchd-dpdk
```

### Step 2B2 (Once per boot) network card setup

Make sure we have no VFs bound to the driver

```
echo '0' | sudo tee -a /sys/class/net/enp3s0f0np0/device/sriov_numvfs
echo '0' | sudo tee -a /sys/class/net/enp3s0f1np1/device/sriov_numvfs
```

Switch the device into switchdev mode

```
sudo devlink dev eswitch set pci/0000:03:00.0 mode switchdev
sudo devlink dev eswitch set pci/0000:03:00.1 mode switchdev
```

### Step 2B3 (Once per OS-install?) OVS configuration

Enable DPDK hardware offloads

```
sudo ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
sudo ovs-vsctl --no-wait set Open_vSwitch . other_config:hw-offload=true
```

Enable huge pages
```
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
```

Configure the DPDK allow-list to discover the network card at 03:00 with both
physical ports (PFs) and VFs 0-1 for each. Also set some other
[acceleration options](https://doc.dpdk.org/guides/nics/mlx5.html).

```
sudo ovs-vsctl --no-wait set Open_vSwitch . \
    other_config:dpdk-extra="-a 0000:03:00.0,representor=pf[0,1]vf[0-1],dv_flow_en=1,dv_xmeta_en=1,dv_esw_en=1"
```

Restart OVS to load the new configuration

```
sudo systemctl restart openvswitch-switch
```

Set up the physical functions (in this case to allow jumbo frames plus some
extra room for things like vxlan or geneve headers):
Set the PFs down

```
sudo ip link set down dev enp3s0f0np0
sudo ip link set down dev enp3s0f1np1
```

Create the bonding interface and link the PF to the bond

```
sudo ip link add dev bond0 type bond mode active-backup miimon 100
sudo ip link set dev enp3s0f0np0 master bond0
sudo ip link set dev enp3s0f1np1 master bond0
```

Set the MTU on the PFs and bond to allow for jumbo frames (in this case 9000
bytes plus some extra space for L2 headers and things like vxlan or geneve)

```
sudo ip link set mtu 9080 dev enp3s0f0np0
sudo ip link set mtu 9080 dev enp3s0f1np1
sudo ip link set mtu 9080 dev bond0
```

NB: you should wait until the LAG state is initialized ("active") before any
VFs are bound, or the VF LAG offloading may fail.

```
while ! [ $(sudo cat /sys/kernel/debug/mlx5/0000:03:00.0/lag/state) == "active" ]; do printf .; sleep 1; done; echo
```

Now we can create some VFs, as needed

```
echo '2' | sudo tee -a /sys/class/net/enp3s0f0np0/device/sriov_numvfs
```

Create an OVS bridge for the physical network

```
sudo ovs-vsctl add-br br-phy \
    -- set Bridge br-phy datapath_type=netdev \
    -- br-set-external-id br-phy bridge-id br-phy \
    -- set bridge br-phy fail-mode=standalone \
        other_config:hwaddr=$(cat /sys/class/net/bond0/address)
```

Add the bond to the bridge

```
sudo ovs-vsctl add-port br-phy p0 \
    -- set Interface p0 type=dpdk mtu_request=9080 \
       options:dpdk-lsc-interrupt=true \
       options:dpdk-devargs=0000:03:00.0
```

Set an IP address for the br-phy bridge

```
sudo ip addr add 192.168.9.2/24 dev br-phy
```

Create an OVS bridge for the VXLAN

```
sudo ovs-vsctl add-br br-vxlan \
    -- set Bridge br-vxlan datapath_type=netdev \
    -- br-set-external-id br-vxlan bridge-id br-vxlan \
    -- set bridge br-vxlan fail-mode=standalone
```

Add a representor for the VF to the vxlan bridge

```
sudo ovs-vsctl add-port br-vxlan pf0vf0 \
    -- set Interface pf0vf0 mtu_request=9080 \
        type=dpdk options:dpdk-devargs=0000:03:00.0,representor=[0]
```

Add a vxlan tunnel port to the vxlan bridge

```
sudo ovs-vsctl add-port br-vxlan vxlan0 \
    -- set interface vxlan0 type=vxlan \
        options:local_ip=192.168.9.2 options:remote_ip=192.168.9.1 \
        options:key=42 options:dst_port=4789
```

Bring all of the devices up

```
sudo ip link set up dev enp3s0f0np0
sudo ip link set up dev enp3s0f1np1
sudo ip link set up dev bond0
sudo ip link set up dev enp3s0f0r0
sudo ip link set up dev br-phy
sudo ip link set up dev br-vxlan
```

Next, we need to bind the VF to the vfio driver on the host. First, load the
vfio driver and let it know that it should claim this type of device:

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
sudo ip addr add dev ens4 192.168.10.2/24
sudo ip link set dev ens4 up mtu 9000
```

Problem: works, but with the bond in place a VF will not fail over to the other
PF (e.g. VF LAG is not working). This might be an issue with the VF not being
marked as trusted, but I get a "RTNETLINK answers: Operation not permitted"
error when I try to set the trust with the ip command.

## Approach 3 using switchdev and tc flower

I wasn't able to get any of the tc flower offloading working with the version
of the mlx5 driver in debian 13 despite many hours of trying. I finally gave up
and tried installing the proprietary driver and then things just worked.
The approach below more or less follows
[the Nvidia documentation](https://docs.nvidia.com/doca/sdk/ovs-kernel+hardware+acceleration/index.html).

### Step 2C1 Install the Nvidia ConnectX DOCA drivers (once per OS install)

First, download the debian bookworm version of the driver and a required
package from bookworm (that's no longer in debian trixie):

```
wget https://www.mellanox.com/downloads/DOCA/DOCA_v3.1.0/host/doca-host_3.1.0-091000-25.07-debian125_amd64.deb
wget http://http.us.debian.org/debian/pool/main/libj/libjsoncpp/libjsoncpp25_1.9.5-4_amd64.deb
```

Next, install the packages

```
sudo dpkg -i libjsoncpp25_1.9.5-4_amd64.deb
sudo dpkg -i doca-host_3.1.0-091000-25.07-debian125_amd64.deb
sudo apt-get update
sudo apt-get -y install doca-networking
```

Reload the new driver version.

```
sudo reboot
#  Note: seems like the following should work instead, but I was still getting
#  symbol errors in dmesg
# sudo rmmod mlx5_fwctl mlx5_ib mlx5_core mlxdevm mlx_compat mlxfw
# sudo modprobe mlx5_core
```

Make sure we have no VFs bound to the driver

```
echo '0' | sudo tee -a /sys/class/net/enp3s0f1np1/device/sriov_numvfs
echo '0' | sudo tee -a /sys/class/net/enp3s0f0np0/device/sriov_numvfs
```

Switch the device into switchdev mode

```
sudo devlink dev eswitch set pci/0000:03:00.0 mode switchdev
sudo devlink dev eswitch set pci/0000:03:00.1 mode switchdev
```

Set up a bond device using the linux kernel stack.

```
sudo ip link add dev bond0 type bond mode active-backup miimon 100
sudo ip link set dev enp3s0f0np0 master bond0
sudo ip link set dev enp3s0f1np1 master bond0
sudo ip link set dev bond0 up
sudo ip addr add 192.168.9.2/24 dev bond0
```

NB: you should wait until the LAG state is initialized ("active") before any
VFs are bound, or the VF LAG offloading may fail.

```
while ! [ $(sudo cat /sys/kernel/debug/mlx5/0000:03:00.0/lag/state) == "active" ]; do printf .; sleep 1; done; echo
```

Now we can create some VFs, as needed

```
echo '2' | sudo tee -a /sys/class/net/enp3s0f0np0/device/sriov_numvfs
```

Next, start open-vswitch and enable hardware offload

```
sudo systemctl start openvswitch-switch.service
sudo ovs-vsctl set Open_vSwitch . other_config:hw-offload=true
sudo systemctl restart openvswitch-switch.service
```

Create an ovs bridge and add the bond and a VF representor interface

```
sudo ovs-vsctl add-br ovs-sriov
sudo ovs-vsctl add-port ovs-sriov enp3s0f0r0
```

We could do VLAN tagging, but let's use a vxlan tunnel instead:

```
ovs-vsctl add-port ovs-sriov vxlan0 \
    -- set interface vxlan0 type=vxlan \
        options:local_ip=192.168.9.2 \
        options:remote_ip=192.168.9.1 \
        options:key=42
```

Optional: set up jumbo frames (e.g. 9000 bytes plus ~80 bytes for L2 headers
from vxlan, geneve, or similar).  Note that we probably want to adjust the
mtu of the vxlan subnet regardless to provide room for the vxlan headers.

```
sudo ip link set dev enp3s0f0np0 mtu 9080
sudo ip link set dev enp3s0f1np1 mtu 9080
sudo ip link set dev bond0 mtu 9080
sudo ip link set dev enp3s0f0r0 mtu 9000
```

Set the bridge and representor to the up state

```
sudo ip link set dev ovs-sriov up
sudo ip link set dev enp3s0f0r0 up
```

Next, we need to bind the VF to the vfio driver on the host. First, load the
vfio driver and let it know that it should claim this type of device:

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
sudo ip addr add dev ens4 192.168.10.2/24
sudo ip link set dev ens4 up mtu 9000
```

## Other possible approaches not used

### vDPA

A newer technology that allows SR-IOV-like performance for a VM using a VirtIO
like driver, basically by creating a standard interface for hardware to expose
(much like NVMe has done for storage). This would allow for things like
live-migration of VMs between machines even with NICs from different vendors.
It sounds like it will be a great technology, but is not fully mature yet and
will require newer hardware (e.g. a ConnectX 6) than what I have.

### DOCA

A proprietary NVIDIA interface that they state will be the only supported
offloading interface for new functionality. Requires a ConnectX-6 or higher,
so testing it was outside of the scope for this project.

## Misc notes

  - Changing the switch mode via devlink from legacy to switchdev seems to
    drop the number of channels from 32 to 1, which hurts performance (e.g.
    iperf3 ~90 Gbps drops to ~30 Gbps). This can be fixed with ethtool, e.g.
    ```
    sudo ethtool -L enp3s0f0np0 combined 32
    ```
