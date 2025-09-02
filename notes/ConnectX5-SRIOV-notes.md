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

## Approach using iproute2 functionality

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

### Step 2 set up host machine networking (on each boot of the host machine)

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

### Step 3 set up the bond on the vm (on each boot of the VM)

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

## Other possible approaches

### DPDK

Nvidia has
[published results](https://fast.dpdk.org/doc/perf/DPDK_22_03_NVIDIA_Mellanox_NIC_performance_report.pdf)
showing line-rate speeds from KVM with a carefully tuned setup with this card.
This might be a good option, but the DPDK tools are a completely different code
path than the normal linux networking and thus seemed like a more niche skillset
to have to learn.

### Switchdev, tc-flower

Switchdev and tc-flower seem like the future of linux network offloading.
Unfortunately with this card, the debian 13 kernel/drivers, and the minimal
tuning I was able to figure out it was not nearly as performant
as the legacy pathway. Just using devlink to switch the device from legacy
to switchdev mode decreased the throughput from ~90 Gbps to ~30 Gbps, and this
did not seem to improve with various settings I tried. This appears to allow for
much more general offloading than the iproute2 path (e.g. using tc rules to
do routing, firewalls, etc), and I hope to play with it more on the future in a
setting where it has a lower performance penalty.

### Open v-switch

This seems like a very useful bit of software for both providing richer switch
functionality (e.g. RTSP) and allowing for sophisticated network topologies
for VMs while supporting hardware offloading either through tc/switchdev or
through DPDK. In my experiments I found it easy to use, but it dropped the
iperf3 performance with switchdev to ~12 Gbps, so didn't seem to be a good
fit with this hardware for this use case (at least with my current hardware
and skillset).

### vDPA

A newer technology that allows the use of the virtio device driver in the VM
talking almost directly to the underlying hardware. This requires newer
hardware (e.g. a ConnectX-6 Dx). It has some advantages like making migration
of virtual machines easier, but sounds like it as not as performant as SR-IOV
and the hardware requirement puts it out of scope for this project.
