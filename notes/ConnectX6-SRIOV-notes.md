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
    seems to be 5 very consistent *57.4 Gb/s* in each direction. While this
    isn't true line-rate encryption, it's probably close enough for my current
    use-case (and upgrading to a ConnectX-7 would fix this if needed).

  - It appears that ipsec offloading [is not currently supported over bonds
    (e.g. VF-LAG)](
    https://forums.developer.nvidia.com/t/bluefield-2-or-connectx-6-dx-crypto-enable-bonding-lacp-ipsec/341359
    ), except possibly in an active-backup configuration (although I've
    so far been unable to get even this configuration to work). This may
    create problems for RoCE fail-over scenarios.

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

| Approach                 | iperf3/1500/2 (Gb/s) | iperf3/9000/2 (Gb/s) | iperf3/9000/6 (Gb/s) | ping mean (us) | ping mdev (us) |
| ------------------------ | -------------------- | -------------------- | -------------------- | -------------- | -------------- |
| ovs/tc + VXLAN           |        TBD           |         TBD          |          TBD         |       TBD      |      TBD       |
| ovs/tc + VXLAN + ipsec   |        TBD           |         TBD          |          TBD         |       TBD      |      TBD       |


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

Some features, including multi-port eswitch and ip-sec over an active-passive
bond, may require the following setting (cargo-culting from the
[DDPK multiport eswitch documentation-](
https://doc.dpdk.org/guides/nics/mlx5.html#multiport-e-switch) )

```
sudo mstconfig --dev 03:00.0 set LAG_RESOURCE_ALLOCATION=1
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

WIP: This seems to be a working example for the single PF case, but does
not yet handle the bonding/failover case.

```
#!/bin/bash

set -xeuo pipefail

ENABLE_IPSEC=true

case $(hostname) in

        aratinga)
                PF=enp3s0f0np0
                VF=enp3s0f0v0
                REPRESENTOR=enp3s0f0r0
                PF_BUSID=pci/0000:03:00.0
                LOCAL_VTEP_IP=192.168.80.2
                LOCAL_VF_IP=192.168.90.2
                REMOTE_VTEP_IP=192.168.80.3
                REMOTE_VF_IP=192.168.90.3
                PSK_OUT=0x20f01f80a26f633d85617465686c32552c92c42f
                PSK_IN=0x6cb228189b4c6e82e66e46920a2cde39187de4ba
                REQID_OUT=0x00000011
                REQID_IN=0x00000013
                SPI_OUT=0x00000003
                SPI_IN=0x00000007
                ;;

        pyrrhura)
                PF=enp3s0f0np0
                VF=enp3s0f0v0
                REPRESENTOR=enp3s0f0r0
                PF_BUSID=pci/0000:03:00.0
                LOCAL_VTEP_IP=192.168.80.3
                LOCAL_VF_IP=192.168.90.3
                REMOTE_VTEP_IP=192.168.80.2
                REMOTE_VF_IP=192.168.90.2
                PSK_OUT=0x6cb228189b4c6e82e66e46920a2cde39187de4ba
                PSK_IN=0x20f01f80a26f633d85617465686c32552c92c42f
                REQID_OUT=0x00000013
                REQID_IN=0x00000011
                SPI_OUT=0x00000007
                SPI_IN=0x00000003
                ;;

        *)
                echo "unrecognized hostname \"$(hostname)\" -  please edit $0" \
                        "to add hostname and ip addresses" 1>&2
                exit 1
                ;;
esac

if $ENABLE_IPSEC; then
        sudo ip xfrm state flush
        sudo ip xfrm policy flush
fi

echo '0' | sudo tee -a /sys/class/net/${PF}/device/sriov_numvfs
sudo devlink dev eswitch set ${PF_BUSID} mode legacy
sudo devlink dev param set ${PF_BUSID} name flow_steering_mode value dmfs cmode runtime
if $ENABLE_IPSEC; then
        echo full | sudo tee /sys/class/net/${PF}/compat/devlink/ipsec_mode
fi
sudo devlink dev eswitch set ${PF_BUSID} mode switchdev
echo '2' | sudo tee -a /sys/class/net/${PF}/device/sriov_numvfs

sudo ip addr replace ${LOCAL_VTEP_IP}/24 dev ${PF}
sudo ip link set dev ${PF} mtu 9216 up

sudo ip link set ${REPRESENTOR} mtu 9000 up

sudo ip netns add ns0 || true
sudo ip link set dev ${VF} netns ns0
sudo ip netns exec ns0 ip addr replace dev ${VF} ${LOCAL_VF_IP}/24
sudo ip netns exec ns0 ip link set dev ${VF} mtu 9000 up

if $ENABLE_IPSEC; then
        sudo ip xfrm state add \
            src ${LOCAL_VTEP_IP}/24 \
            dst ${REMOTE_VTEP_IP}/24 \
            proto esp \
            spi ${SPI_OUT} \
            reqid ${REQID_OUT} \
            mode transport \
            aead 'rfc4106(gcm(aes))' ${PSK_OUT} 128 \
            offload packet \
            dev ${PF} dir out \
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
            offload packet dev ${PF} dir in \
            sel \
                src ${REMOTE_VTEP_IP} \
                dst ${LOCAL_VTEP_IP} \
                flag esn \
                replay-window 64
        sudo ip xfrm policy add \
            src ${LOCAL_VTEP_IP} \
            dst ${REMOTE_VTEP_IP} \
            offload packet dev ${PF} \
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
            offload packet dev ${PF} \
            dir in \
            tmpl \
                src ${REMOTE_VTEP_IP}/24 \
                dst ${LOCAL_VTEP_IP}/24 \
                proto esp \
                reqid ${REQID_IN} \
                mode transport \
                priority 12
#       sudo ip xfrm policy add \
#           src ${REMOTE_VTEP_IP} \
#           dst ${LOCAL_VTEP_IP} \
#           dir fwd \
#           tmpl \
#               src ${REMOTE_VTEP_IP}/24 \
#               dst ${LOCAL_VTEP_IP}/24 \
#               proto esp \
#               reqid ${REQID_IN} \
#               mode transport \
#               priority 12
fi

sudo apt install -y openvswitch-switch openvswitch-vtep
if $ENABLE_IPSEC; then
        sudo apt install -y openvswitch-ipsec strongswan-starter
fi
sudo ovs-vsctl del-br br-ovs || true
sudo ovs-vsctl add-br br-ovs
sudo ovs-vsctl add-port br-ovs ${REPRESENTOR}
sudo ovs-vsctl add-port br-ovs vxlan1 \
    -- set interface vxlan1 type=vxlan \
    options:local_ip=${LOCAL_VTEP_IP} \
    options:remote_ip=${REMOTE_VTEP_IP} \
    options:key=1024 \
    options:dst_port=4789
```

One check that the traffic is encrypted is by looking at the number of bytes
and packets with either ethtool:

```
sudo ethtool -S enp3s0f0np0 | grep ipsec
```

or with `ip xfrm state`:

```
sudo ip -s xfrm state
```

