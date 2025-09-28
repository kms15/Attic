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
vfio-pci driver, so first unbind them from the mlx5 driver:

```
echo "0000:03:00.3" | sudo tee /sys/bus/pci/drivers/mlx5_core/unbind
echo "0000:03:02.3" | sudo tee /sys/bus/pci/drivers/mlx5_core/unbind
```

Oddly enough the vfio-pci driver would not allow the VFs to be bound until
the pcie device id had been registered with the driver, but at that point it
bound both of the unbound devices automatically. Thus the following worked to
bind both VFs

```
echo $(cat /sys/bus/pci/devices/0000\:03\:00.3/{vendor,device}) \
    | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id
```

Additional VFs would need to be bound with syntax similar to the unbind
commands above, however (catting VFs the PCIe address to the vfio driver's
bind instead of the mlx5_core's bind).

Next we set the vf's mac addresses. I'm not 100% sure this is needed, but it
was included in some of the SR-IOV examples and bonds weren't working when I
tried getting things to work without it (but that may have been broken by
something else during that experiment). Obviously these should be chosen to be
globally unique.

```
sudo ip link set enp3s0f0np0 vf 0 mac e2:11:22:33:11:00
sudo ip link set enp3s0f0np1 vf 0 mac e2:11:22:33:11:01
sudo ip link set enp3s0f1np1 vf 0 mac e2:11:22:33:11:10
sudo ip link set enp3s0f1np1 vf 1 mac e2:11:22:33:11:11
```

Run qemu, using pci-passthrough for one VF from each PF (physical function, i.e.
port). In this example, you can log in to the VM with root with a blank
password.

```
wget https://cloud.debian.org/images/cloud/trixie/20250814-2204/debian-13-nocloud-amd64-20250814-2204.qcow2
sudo qemu-system-x86_64 -accel kvm -nographic -m 8G -cpu host -smp 16 \
    -drive file=debian-13-nocloud-amd64-20250814-2204.qcow2 \
    -device vfio-pci,host=0000:03:00.3  \
    -device vfio-pci,host=0000:03:02.3
```

### Step 2A2 set up the bond on the vm (on each boot of the VM)

Load the bonding kernel module with ~100ms link health checks

```
modprobe bonding miimon=100
```

Create the bonding interface

```
sudo ip link add dev bond0 type bond mode active-backup
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
ip link set dev ens4 up
ip link set dev ens5 up
ip link set dev bond0 up
```

Add an ip address and subnet to the bond

```
ip a add 192.168.9.3/24 dev bond0
```

## Approach 2 using DPDK and OVS (WIP)


### Step 2B1 (once per OS-install) install prerequisites

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

Set each of the physical functions (PFs, corresponding to the two ports on the
network card) to have 2 virtual functions (works fine with 16 VFs and probably
higher).

```
echo '2' | sudo tee -a /sys/class/net/enp3s0f1np1/device/sriov_numvfs
echo '2' | sudo tee -a /sys/class/net/enp3s0f0np0/device/sriov_numvfs
```

The VFs need to be unbound before switching to switchdev mode:

```
echo "0000:03:00.3" | sudo tee /sys/bus/pci/drivers/mlx5_core/unbind
echo "0000:03:00.3" | sudo tee /sys/bus/pci/drivers/mlx5_core/unbind
echo "0000:03:02.3" | sudo tee /sys/bus/pci/drivers/mlx5_core/unbind
echo "0000:03:02.3" | sudo tee /sys/bus/pci/drivers/mlx5_core/unbind
```

The PFs can then be set into switchdev mode:

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
sudo ovs-vsctl set Open_vSwitch . \
    other_config:dpdk-extra="-a 0000:03:00.0,representor=pf[0,1]vf[0-1],dv_flow_en=1,dv_xmeta_en=1,sys_mem_en=1"
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

Load the bonding kernel module with ~100ms link health checks

```
sudo modprobe bonding miimon=100
```

Create the bonding interface and link the PF to the bond

```
sudo ip link add dev bond0 type bond mode active-backup
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

Create an OVS bridge for DPDK

```
sudo ovs-vsctl add-br br0-ovs \
    -- set Bridge br0-ovs datapath_type=netdev \
    -- br-set-external-id br0-ovs bridge-id br0-ovs \
    -- set bridge br0-ovs fail-mode=standalone
```

Add physical functions to the bridge

```
sudo ovs-vsctl add-port br0-ovs p0 \
    -- set Interface p0 type=dpdk mtu_request=9080 \
       options:dpdk-lsc-interrupt=true \
       options:dpdk-devargs=0000:03:00.0
```

Add the representors for the VFs

```
sudo ovs-vsctl add-port br0-ovs pf0vf0 \
    -- set Interface pf0vf0 mtu_request=9080 \
        type=dpdk options:dpdk-devargs=0000:03:00.0,representor=[0]
```

Bring all of the devices up

```
sudo ip link set up dev enp3s0f0np0
sudo ip link set up dev enp3s0f1np1
sudo ip link set up dev bond0
sudo ip link set up dev enp3s0f0r0
sudo ip link set up dev br0-ovs
```

Problem: works, but with the bond in place a VF will not fail over to the other
PF (e.g. VF LAG is not working). This might be an issue with the VF not being
marked as trusted, but I get a "RTNETLINK answers: Operation not permitted"
error when I try to set the trust with the ip command.

## Other possible approaches not used

### Switchdev, tc-flower

Switchdev and tc-flower seem like a promising kernel-supported method for
hardware offloading.
Unfortunately with this card, the debian 13 kernel/drivers, and the minimal
tuning I was able to figure out it was not nearly as performant
as the legacy pathway. Notes so far:

  - Changing the switch mode via devlink from legacy to switchdev seems to
    drop the number of channels from 32 to 1, which hurts performance (e.g.
    iperf3 ~90 Gbps drops to ~30 Gbps). This can be fixed with ethtool, e.g.
    ```
    sudo ethtool -L enp3s0f0np0 combined 32
    ```

  - Even with that change I can't seem to get the kernel to offload any of the
    tc rules to hardware. Although the NVIDIA documentation suggests this should
    be possible, I tried a lot of things without success and the general
    consensus in forums seems to be that you need a ConnectX 6 or newer for
    this to work.  I could upgrade the NICs, but right now the costs seem to
    outweigh the potential benefits.

  - The tc flower rules are quite low level (e.g. they don't even implement
    mac learning?) and would probably be much easier to use with a higher
    level tool running on top (e.g. open vswitch).


### vDPA

A newer technology that allows SR-IOV-like performance for a VM using a VirtIO
like driver, basically by creating a standard interface for hardware to expose
(much like NVMe has done for storage). This would allow for things like
live-migration of VMs between machines even with NICs from different vendors.
It sounds like it will be a great technology, but is not fully mature yet and
will require newer hardware (e.g. a ConnectX 6) than what I have.
