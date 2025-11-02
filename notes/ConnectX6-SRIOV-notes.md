# SR-IOV with a ConnectX-6

## Goal

Share a 100 Gbps dual-port network adapter with multiple VMs in a way that
allows the VMs to achieve near line-speed with active-passive fail-over between
ports (e.g. upstream switches) and allows for the VMs to be isolated to
different vxlans with ipsec tunnels providing transport encryption of all
intra-VM traffic.

## Materials and Methods

### Hardware

Two machines each with Epyc 4545P processors and ConnectX-6 Dx cards
(MCX623106AC) in x8 PCIe slots.

### Software stack used

From [prior experiments with the Mellanox ConnectX-5](ConnectX5-SRIOV-notes.md)
the switchdev/tc software stack seemed to provide a good balance of offload
performance, features, and low idle CPU usage, so it was used for this set of
experiments.

### Network performance measurements

The throughput was measured with iperf3 with different MTU
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
| ovs/tc + VXLAN   |        TBD           |         TBD          |          TBD         |       TBD      |      TBD       |


## Conclusions

- TBD

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
[latest matching firmware](https://network.nvidia.com/support/firmware/connectx6dx/)

```
wget https://www.mellanox.com/downloads/firmware/fw-ConnectX6Dx-rel-22_43_8002-MCX623106AC-CDA_Ax-UEFI-14.37.50-FlexBoot-3.7.500.signed.bin.zip
unzip fw-ConnectX6Dx-rel-22_43_8002-MCX623106AC-CDA_Ax-UEFI-14.37.50-FlexBoot-3.7.500.signed.bin.zip
```

Install the firmware and reboot the card with the new firmware

```
sudo mstflint --dev 03:00.0 -i fw-ConnectX6Dx-rel-22_43_8002-MCX623106AC-CDA_Ax-UEFI-14.37.50-FlexBoot-3.7.500.signed.bin burn
sudo mstfwreset --dev 03:00.0 reset
```

Confirm ipsec acceleration is available:

Example of a working card:
```
$ sudo ethtool -k enp3s0f0np0 | grep "esp\|tls"
tx-esp-segmentation: on
esp-hw-offload: on [fixed]
esp-tx-csum-hw-offload: on [fixed]
tls-hw-tx-offload: on
tls-hw-rx-offload: off
tls-hw-record: off [fixed]
$ sudo dmesg | grep -i ipsec
[   10.065419] mlx5_core 0000:03:00.0: mlx5e: IPSec ESP acceleration enabled
[   10.857570] mlx5_core 0000:03:00.1: mlx5e: IPSec ESP acceleration enabled
```

Example of a non-working card:

```
$ sudo ethtool -k enp3s0f0np0 | grep "esp\|tls"
tx-esp-segmentation: off [fixed]
esp-hw-offload: off [fixed]
esp-tx-csum-hw-offload: off [fixed]
tls-hw-tx-offload: off [fixed]
tls-hw-rx-offload: off [fixed]
tls-hw-record: off [fixed]
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

Reboot the system to set up the new PCIe BAR, etc. for SR-IOV

```
sudo reboot
```

# ipsec approach #1

For this approach, we will loosely follow the example in [the NVIDIA OFED
documents](
https://docs.nvidia.com/networking/display/mlnxofedv24010331/ipsec+full+offload
) to set up an ipsec encrypted connection between two VFs.

No VFs can be bound to the driver when some of these settings are changed.
Rather than unbinding the VFs, we'll just set the number of VFs to 0 (then
set the number of VFs back once we've set things up).

```
echo '0' | sudo tee -a /sys/class/net/enp3s0f0np0/device/sriov_numvfs
```

Change the flow steering mode to device-managed flow steering (where hardware
flow steering entries are set via firmware, rather than directly by the driver
(per documentation required for ipsec acceleration), then set the nic to
switchdev mode.

```
sudo devlink dev param set pci/0000:03:00.0 name flow_steering_mode value dmfs cmode runtime
sudo devlink dev eswitch set pci/0000:03:00.0 mode switchdev
```

Set up the desired number of VFs (choosing 2 as an arbitrary example).

```
echo '2' | sudo tee -a /sys/class/net/enp3s0f0np0/device/sriov_numvfs
```

Give the physical function (PF) an address and bring it up with an MTU of 9216.

```
sudo ip addr add 192.168.80.2/24 dev enp3s0f0np0
sudo ip link set dev enp3s0f0np0 mtu 9216 up
```

Bring up the representor for VF0 (with a smaller MTU to allow room for vxlan
and ipsec headers).

```
sudo ip link set enp3s0f0r0 mtu 9000 up
```

Following the example, we bring up the VF in a different namespace (presumably
to prevent direct routing of ipsec packets between interfaces without
encrypting them first).

```
sudo ip netns add ns0
sudo ip link set dev enp3s0f0v0 netns ns0
sudo ip netns exec ns0 ip addr add dev enp3s0f0v0 192.168.90.2/24
sudo ip netns exec ns0 ip link set dev enp3s0f0v0 mtu 9000 up
```

Configure ipsec states and policies. (Note: I'm still wrapping my head around
these - the spi and reqid appear to allow for relatively arbitrary choices, but
there may be some complexities with things like key rotation that I haven't
appreciated yet). We probably will want to use something like strongswan in
the long run in order to handle things like a proper key exchange setup, but
for testing we'll just use hard-coded pre-shared keys.

```
sudo ip xfrm state add \
    src 192.168.80.2/24 dst 192.168.80.3/24 \
    proto esp spi 0x00000003 reqid 0x00000003 mode transport \
    aead 'rfc4106(gcm(aes))' 0x20f01f80a26f633d85617465686c32552c92c42f 128 \
    offload packet dev enp3s0f0np0 dir out sel \
    src 192.168.80.2/24 dst 192.168.80.3/24 \
    flag esn replay-window 64
sudo ip xfrm state add \
    src 192.168.80.3/24 dst 192.168.80.2/24 \
    proto esp spi 0x00000007 reqid 0x00000007 mode transport \
    aead 'rfc4106(gcm(aes))' 0x6cb228189b4c6e82e66e46920a2cde39187de4ba 128 \
    offload packet dev enp3s0f0np0 dir in sel \
    src 192.168.80.3/24 dst 192.168.80.2/24 \
    flag esn replay-window 64
sudo ip xfrm policy add \
    src 192.168.80.2/24 dst 192.168.80.3/24 \
    offload packet dev enp3s0f0np0 dir out tmpl \
    src 192.168.80.2/24 dst 192.168.80.3/24 \
    proto esp reqid 0x00000003 mode transport priority 12
sudo ip xfrm policy add \
    src 192.168.80.3/24 dst 192.168.80.2/24 \
    offload packet dev enp3s0f0np0 dir in tmpl \
    src 192.168.80.3/24 dst 192.168.80.2/24 \
    proto esp reqid 0x00000007 mode transport priority 12
```

Here's an example of what the other side of the link might look like (since
there are a few things that would need to be changed):

```
sudo ip xfrm state add \
    src 192.168.80.2/24 dst 192.168.80.3/24 \
    proto esp spi 0x00000003 reqid 0x00000003 mode transport \
    aead 'rfc4106(gcm(aes))' 0x20f01f80a26f633d85617465686c32552c92c42f 128 \
    offload packet dev enp3s0f0np0 dir in sel \
    src 192.168.80.2/24 dst 192.168.80.3/24 \
    flag esn replay-window 64
sudo ip xfrm state add \
    src 192.168.80.3/24 dst 192.168.80.2/24 \
    proto esp spi 0x00000007 reqid 0x00000007 mode transport \
    aead 'rfc4106(gcm(aes))' 0x6cb228189b4c6e82e66e46920a2cde39187de4ba 128 \
    offload packet dev enp3s0f0np0 dir out sel \
    src 192.168.80.3/24 dst 192.168.80.2/24 \
    flag esn replay-window 64
sudo ip xfrm policy add \
    src 192.168.80.2/24 dst 192.168.80.3/24 \
    offload packet dev enp3s0f0np0 dir in tmpl \
    src 192.168.80.2/24 dst 192.168.80.3/24 \
    proto esp reqid 0x00000003 mode transport priority 12
sudo ip xfrm policy add \
    src 192.168.80.3/24 dst 192.168.80.2/24 \
    offload packet dev enp3s0f0np0 dir out tmpl \
    src 192.168.80.3/24 dst 192.168.80.2/24 \
    proto esp reqid 0x00000007 mode transport priority 12
```
