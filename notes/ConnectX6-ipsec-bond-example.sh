#!/bin/bash

set -xeuo pipefail

ENABLE_IPSEC=true
USE_TC=true

case $(hostname) in

    aratinga)
        PF0=enp3s0f0np0
        PF1=enp3s0f1np1
        VM_VF=enp3s0f0v0
        VM_VF_REPRESENTOR=enp3s0f0r0
        VM_VF_BUSID=0000:03:00.2
        VM_VF_PF=${PF0}
        VM_VF_NUM=0
        NS_VF=enp3s0f1v0
        NS_VF_REPRESENTOR=enp3s0f1r0
        NS_VF_BUSID=0000:03:02.2
        NS_VF_PF=${PF1}
        NS_VF_NUM=0
        VTEP_SF=enp3s0f0s42
        VTEP_SF_REPRESENTOR=en3f0pf0sf42
        VTEP_SF_NUM=42
        PF0_BUSID=0000:03:00.0
        PF1_BUSID=0000:03:00.1
        LOCAL_BOND_IP=192.168.70.2
        LOCAL_VTEP_IP=192.168.80.2
        LOCAL_VM_VF_IP=192.168.90.2
        LOCAL_VM_VF_MAC=02:00:00:00:00:02 # Note: x2:xx:xx:xx:xx:xx mac can be arbitrary
        LOCAL_NS_VF_IP=192.168.90.4
        LOCAL_NS_VF_MAC=02:00:00:00:00:04 # Note: x2:xx:xx:xx:xx:xx mac can be arbitrary
        REMOTE_BOND_IP=192.168.70.3
        REMOTE_VTEP_IP=192.168.80.3
        PSK_OUT=0x20f01f80a26f633d85617465686c32552c92c42f
        PSK_IN=0x6cb228189b4c6e82e66e46920a2cde39187de4ba
        REQID_OUT=0x00000011
        REQID_IN=0x00000013
        SPI_OUT=0x00000003
        SPI_IN=0x00000007
        ;;

    pyrrhura)
        PF0=enp3s0f0np0
        PF1=enp3s0f1np1
        VM_VF=enp3s0f0v0
        VM_VF_REPRESENTOR=enp3s0f0r0
        VM_VF_BUSID=0000:03:00.2
        VM_VF_PF=${PF0}
        VM_VF_NUM=0
        NS_VF=enp3s0f1v0
        NS_VF_REPRESENTOR=enp3s0f1r0
        NS_VF_BUSID=0000:03:02.2
        NS_VF_PF=${PF1}
        NS_VF_NUM=0
        VTEP_SF=enp3s0f0s42
        VTEP_SF_REPRESENTOR=en3f0pf0sf42
        VTEP_SF_NUM=42
        PF0_BUSID=0000:03:00.0
        PF1_BUSID=0000:03:00.1
        LOCAL_BOND_IP=192.168.70.3
        LOCAL_VTEP_IP=192.168.80.3
        LOCAL_VM_VF_IP=192.168.90.3
        LOCAL_VM_VF_MAC=02:00:00:00:00:03 # Note: x2:xx:xx:xx:xx:xx mac can be arbitrary
        LOCAL_NS_VF_IP=192.168.90.5
        LOCAL_NS_VF_MAC=02:00:00:00:00:05 # Note: x2:xx:xx:xx:xx:xx mac can be arbitrary
        REMOTE_BOND_IP=192.168.70.2
        REMOTE_VTEP_IP=192.168.80.2
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

OVERLAY_MTU=9000
UNDERLAY_MTU=9216

if $ENABLE_IPSEC; then
    sudo ip xfrm state flush
    sudo ip xfrm policy flush
fi

sudo ip link delete bond0 || true
sudo ip link set ${PF0} down
sudo ip link set ${PF1} down

sudo ip addr del ${LOCAL_VTEP_IP}/32 dev lo || true

sudo devlink port del ${VTEP_SF_REPRESENTOR} || true
sudo ovs-vsctl del-br br-ovs || true
sudo ip link del dev br-overlays || true
sudo ip link del dev br-underlay || true
sudo ip link del dev br-uplink || true
sudo ip link delete vxlan100 || true

# Note: we can only set a VF to "trusted" while the NIC is in legacy mode, but
# some settings can not be changed if VFs are bound to the driver and the bond
# must be created before the VFs are initialized by the driver for RoCEv2
# offloading to work. We thus unbind all of the VFs from the driver and then
# rebind them once we are ready to use them. For this example we'll just use a
# single VF (but the extension to multiple VFs should be obvious).
echo '0' | sudo tee -a /sys/class/net/${PF0}/device/sriov_numvfs
echo '0' | sudo tee -a /sys/class/net/${PF1}/device/sriov_numvfs
echo '1' | sudo tee -a /sys/class/net/${PF0}/device/sriov_numvfs
echo '1' | sudo tee -a /sys/class/net/${PF1}/device/sriov_numvfs
echo "${VM_VF_BUSID}" | sudo tee /sys/bus/pci/drivers/mlx5_core/unbind || true
echo "${VM_VF_BUSID}" | sudo tee /sys/bus/pci/drivers/vfio-pci/unbind || true
echo "${NS_VF_BUSID}" | sudo tee /sys/bus/pci/drivers/mlx5_core/unbind || true
echo "${NS_VF_BUSID}" | sudo tee /sys/bus/pci/drivers/vfio-pci/unbind || true

sudo devlink dev eswitch set pci/${PF0_BUSID} mode legacy
sudo devlink dev eswitch set pci/${PF1_BUSID} mode legacy
sudo devlink dev param set pci/${PF0_BUSID} name flow_steering_mode value dmfs cmode runtime
sudo devlink dev param set pci/${PF1_BUSID} name flow_steering_mode value dmfs cmode runtime
sudo ip link set ${VM_VF_PF} vf ${VM_VF_NUM} trust on spoofchk off mac ${LOCAL_VM_VF_MAC}
sudo ip link set ${NS_VF_PF} vf ${NS_VF_NUM} trust on spoofchk off mac ${LOCAL_NS_VF_MAC}
sudo devlink dev eswitch set pci/${PF0_BUSID} mode switchdev
sudo devlink dev eswitch set pci/${PF1_BUSID} mode switchdev

sudo ip link add dev bond0 type bond mode active-backup miimon 100
sudo ip link set dev ${PF0} master bond0
sudo ip link set dev ${PF1} master bond0
sudo ethtool --offload bond0 esp-hw-offload on
sudo ethtool --offload bond0 esp-tx-csum-hw-offload on

sudo ip addr replace ${LOCAL_BOND_IP}/24 dev bond0
sudo ip link set dev ${PF0} mtu ${UNDERLAY_MTU} up
sudo ip link set dev ${PF1} mtu ${UNDERLAY_MTU} up
sudo ip link set dev bond0 mtu ${UNDERLAY_MTU} up

sudo ip link set ${VM_VF_REPRESENTOR} mtu ${OVERLAY_MTU} up
sudo ip link set ${NS_VF_REPRESENTOR} mtu ${OVERLAY_MTU} up

sudo modprobe vfio-pci || true
echo $(cat /sys/bus/pci/devices/${VM_VF_BUSID}/{vendor,device}) \
| sudo tee -a /sys/bus/pci/drivers/vfio-pci/new_id || true
echo "${VM_VF_BUSID}" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind

echo "${NS_VF_BUSID}" | sudo tee /sys/bus/pci/drivers/mlx5_core/bind
sudo ip netns add ns0 || true
sudo ip netns add ns1 || true
sudo ip link set dev ${NS_VF} netns ns0
sudo ip netns exec ns0 ip addr replace dev ${NS_VF} ${LOCAL_NS_VF_IP}/24
sudo ip netns exec ns0 ip link set dev ${NS_VF} mtu ${OVERLAY_MTU} up

if $ENABLE_IPSEC; then

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
fi

sudo ip route replace to ${REMOTE_VTEP_IP}/32 nexthop via ${REMOTE_BOND_IP}

# add the VTEP
sudo ip addr add ${LOCAL_VTEP_IP}/32 dev lo

# create the vxlan device
sudo ip link add vxlan100 \
type vxlan \
id 100 \
dstport 4789 \
local ${LOCAL_VTEP_IP} \
remote ${REMOTE_VTEP_IP} \
# nolearning \
sudo ip link set dev vxlan100 mtu ${OVERLAY_MTU} up

# create the overlay bridge and add the vxlan and VF representor interfaces
sudo ip link add br-overlays type bridge \
stp_state 0 \
vlan_filtering 1 \
vlan_default_pvid 0 \
mcast_snooping 0
sudo ip link set dev br-overlays up

sudo ip link set dev ${VM_VF_REPRESENTOR} master br-overlays
sudo bridge vlan add vid 100 dev ${VM_VF_REPRESENTOR} pvid untagged

sudo ip link set dev ${NS_VF_REPRESENTOR} master br-overlays
sudo bridge vlan add vid 100 dev ${NS_VF_REPRESENTOR} pvid untagged

sudo ip link set dev vxlan100 master br-overlays
sudo bridge vlan add vid 100 dev vxlan100 pvid untagged

# use tc flower rules to offload the vxlan and bridge logic
if ${USE_TC}; then
    sudo tc qdisc add dev vxlan100 ingress
    sudo tc filter add dev vxlan100 ingress \
        protocol all prio 1 flower \
            enc_src_ip ${REMOTE_VTEP_IP} \
            enc_dst_ip ${LOCAL_VTEP_IP} \
            enc_dst_port 4789 \
            ip_flags nofrag \
            enc_key_id 100 \
            dst_mac ${LOCAL_VM_VF_MAC} \
        action tunnel_key unset \
        action mirred egress redirect dev ${VM_VF_REPRESENTOR}
    sudo tc filter add dev vxlan100 ingress \
        protocol all prio 2 flower \
            enc_src_ip ${REMOTE_VTEP_IP} \
            enc_dst_ip ${LOCAL_VTEP_IP} \
            enc_dst_port 4789 \
            ip_flags nofrag \
            enc_key_id 100 \
            dst_mac ${LOCAL_NS_VF_MAC} \
        action tunnel_key unset \
        action mirred egress redirect dev ${NS_VF_REPRESENTOR}

    sudo tc qdisc add dev ${VM_VF_REPRESENTOR} ingress
    sudo tc filter add dev ${VM_VF_REPRESENTOR} ingress \
        protocol all prio 1 flower \
            indev ${VM_VF_REPRESENTOR} \
            dst_mac ${LOCAL_NS_VF_MAC} \
        action mirred egress redirect dev ${NS_VF_REPRESENTOR}
    sudo tc filter add dev ${VM_VF_REPRESENTOR} ingress \
        protocol all prio 2 flower \
            indev ${VM_VF_REPRESENTOR} \
        action tunnel_key set \
            src_ip ${LOCAL_VTEP_IP} \
            dst_ip ${REMOTE_VTEP_IP} \
            dst_port 4789 \
            id 100 \
        action mirred egress redirect dev vxlan100

    sudo tc qdisc add dev ${NS_VF_REPRESENTOR} ingress
    sudo tc filter add dev ${NS_VF_REPRESENTOR} ingress \
        protocol all prio 1 flower \
            indev ${NS_VF_REPRESENTOR} \
            dst_mac ${LOCAL_VM_VF_MAC} \
        action mirred egress redirect dev ${VM_VF_REPRESENTOR}
    sudo tc filter add dev ${NS_VF_REPRESENTOR} ingress \
        protocol all prio 2 flower \
            indev ${NS_VF_REPRESENTOR} \
        action tunnel_key set \
            src_ip ${LOCAL_VTEP_IP} \
            dst_ip ${REMOTE_VTEP_IP} \
            dst_port 4789 \
            id 100 \
        action mirred egress redirect dev vxlan100
fi
