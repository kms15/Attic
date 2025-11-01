## Installing the minimal bootable debian image

The OS drive for this switch is a standard mSATA drive.
You will probably want to save the mSATA drive the device came with (and
possibly back it up to protect against bitrot) and buy a new (and likely
larger) mSATA drive to use with debian. Based on a random forum recommendation
for a robust drive that's known to work, I chose the Transcend
TS512GMSA452T-I, but I believe any drive should work.

For the initial boot, you can just download the latest debian AMD64 nocloud
image, e.g.

```
https://cloud.debian.org/images/cloud/trixie/20251006-2257/debian-13-nocloud-amd64-20251006-2257.qcow2
```

Connect the new mSATA drive to your workstation (e.g. with a[USB to mSATA
adapter](https://sabrent.com/products/ec-ukms?_pos=3&_sid=99b8124ce&_ss=r)).

In these notes we will assume the new drive appears as /dev/sda, but *please
confirm this and adjust these commands as needed or you will overwrite the
wrong drive*.

```
sudo qemu-img convert ~/Downloads/debian-13-nocloud-amd64-20251006-2257.qcow2 /dev/sda
```

Conveniently this image will boot on the switch as-is, including proper
settings for the serial console, so you can just boot the image, connect a
serial cable, and log in as root (with no password by default).

Alternatively we can start a qemu session to configure the image before putting
the mSATA drive in the switch, thus saving us the effort of having to use a
serial cable

```
qemu-system-x86_64 -accel kvm -nographic  -drive file=sn2410.qcow2 \
    -m 8G -smp cores=2 -cpu IvyBridge -machine q35
```

Note that these memory/cpu settings emulate the switch itself, but you might
want to use more cores and memory to speed up the kernel compilation below.

## Basic network configuration

First we need to set up the control plane network adapter (configured here with
dhcp):

```
cat <<EOF | sudo tee /etc/network/interfaces
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

auto eno1
iface eno1 inet dhcp
EOF
```

Next we install and configure ssh access to the switch...

```
sudo apt-update
sudo apt-get install -y openssh-server
```

...disable password authentication...
```
sudo sed -iorig -e "s/#PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
```

...and we add some authorized keys for root.

```
cat <<EOF > ~/.ssh/authorized_keys
sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMIrZlIqJBzDxoyJcg/Keq4HO8crJwn51t25vNTE7cAxAAAABHNzaDo= nk3_kms15_Faraday_498F_touch
sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIP5vMQTCIVnaAxhJaEGmlc72AiXWTJQHagwPA8xv/FanAAAABHNzaDo= nk3_kms15_Faraday_55E3_touch
sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPVUo7AWC0BmNKPxoUgEWI8PxTmlpY2pIotbEgRpsUDkAAAABHNzaDo= nk3_kms15_Faraday_92DD_touch
sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIJHhqK+JE54q819VFQajuLzM52O8JrSnommb+LRln4aeAAAABHNzaDo= nk3_kms15_Dirac_498F_touch
sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPHzNeeZ27WxJyKGexxHOrwj2z4vQrndFpv8byEd41U4AAAABHNzaDo= nk3_kms15_Dirac_55E3_touch
sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIM+UVKQRx0dOeT7wZvX5n7DmvcdtbYEds5NpwL01tceLAAAABHNzaDo= nk3_kms15_Dirac_9FFD_touch
EOF
```

## Building a linux kernel with the Mellanox switch drivers

Useful references:
 - [Debian on Mellanox SN2700](https://ipng.ch/s/articles/2023/11/11/debian-on-mellanox-sn2700-32x100g/)
 - [Debian common kernel-related tasks](https://kernel-team.pages.debian.net/kernel-handbook/ch-common-tasks.html)
 - [Mellanox mlxsw wiki - installing a new kernel](https://github.com/Mellanox/mlxsw/wiki/Installing-a-New-Kerne)

The image we're using only has about 3 GiB of space in the root partition,
which is not enough to build a custom kernel. We thus create a scratch
partition to use for building the kernel and mount it on `/mnt`:

```
sudo apt-get install -y fdisk e2fsprogs
echo "size=16GiB name=scratch type=linux" | sudo sfdisk /dev/sda --append --no-reread
sudo partx --update /dev/sda
sudo mkfs -t ext4 /dev/sda2
sudo mount /dev/sda2 /mnt
cd /mnt
```

Next we install and unpack the current debian linux kernel source
(note that the `$(uname [...] | cut [...])` just gives the current kernel
version, e.g. '6.12'.

```
sudo apt-get install -y linux-source-$(uname -r | cut -d. -f1-2)
tar xaf /usr/src/linux-source-$(uname -r | cut -d. -f1-2).tar.xz
cd linux-source-$(uname -r | cut -d. -f1-2)
```

Now we create a kernel config with the correct settings. First we copy the
current kernel config

```
cp /boot/config-$(uname -r) debian.config
```

We also need a config fragment of options we want to change to enable Mellanox
switch kernel support, in this case copied from the
[Mellanox mlxsw wiki](https://github.com/Mellanox/mlxsw/wiki/Installing-a-New-Kerne)

```
cat <<EOF > mlxsw.config
CONFIG_NET_IPIP=m
CONFIG_NET_IPGRE_DEMUX=m
CONFIG_NET_IPGRE=m
CONFIG_IPV6_GRE=m
CONFIG_IP_MROUTE_MULTIPLE_TABLES=y
CONFIG_IP_MULTIPLE_TABLES=y
CONFIG_IPV6_MULTIPLE_TABLES=y
CONFIG_BRIDGE=m
CONFIG_VLAN_8021Q=m
CONFIG_BRIDGE_VLAN_FILTERING=y
CONFIG_BRIDGE_IGMP_SNOOPING=y
CONFIG_NET_SWITCHDEV=y
CONFIG_NET_DEVLINK=y
CONFIG_MLXFW=m
CONFIG_MLXSW_CORE=m
CONFIG_MLXSW_CORE_HWMON=y
CONFIG_MLXSW_CORE_THERMAL=y
CONFIG_MLXSW_PCI=m
CONFIG_MLXSW_I2C=m
CONFIG_MLXSW_MINIMAL=y
CONFIG_MLXSW_SWITCHX2=m
CONFIG_MLXSW_SPECTRUM=m
CONFIG_MLXSW_SPECTRUM_DCB=y
CONFIG_LEDS_MLXCPLD=m
CONFIG_NET_SCH_PRIO=m
CONFIG_NET_SCH_RED=m
CONFIG_NET_SCH_INGRESS=m
CONFIG_NET_CLS=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_ACT_MIRRED=m
CONFIG_NET_CLS_MATCHALL=m
CONFIG_NET_CLS_FLOWER=m
CONFIG_NET_ACT_GACT=m
CONFIG_NET_ACT_MIRRED=m
CONFIG_NET_ACT_SAMPLE=m
CONFIG_NET_ACT_VLAN=m
CONFIG_NET_L3_MASTER_DEV=y
CONFIG_NET_VRF=m
EOF
```

We next merge the debian config file with the setting in our mlxsw config
fragment

```
./scripts/kconfig/merge_config.sh debian.config mlxsw.config
```

We then disable module signing and debug info

```
scripts/config --disable MODULE_SIG
scripts/config --disable DEBUG_INFO
scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
```

Finally we set any new kernel configurations to their default value

```
make olddefconfig
```

We next install some packages needed to build the kernel (note: cargo-culting
plus adding more when it failed, definitely not an authorative list)

```
sudo apt-get install -y build-essential linux-source bc kmod cpio flex \
    libncurses-dev libelf-dev libssl-dev dwarves bison debhelper
```

We can now build a new kernel. (Note: this takes about 5 and a half hours on
the switch).

```
make clean
time make -j $(nproc) bindeb-pkg
```

We can then install the new kernel using

```
dpkg -i ../linux-image-$(uname -r | cut -f1 -d+)_$(uname -r | cut -f1 -d+)-1_amd64.deb
```

Debian's grub setup seems to not reliably choose the new kernel by default.
To work around this, we can manually uninstall the old kernel:

```
sudo DEBIAN_FRONTEND=noninteractive apt remove -y linux-image-$(uname -r | cut -f1 -d+)+deb13-amd64
```

## misc setup

Set the hostname

```
sudo hostnamectl set-hostname phoebastria
```

## Example of a bridge with a VLAN

We first create a bridge. Per [the mellanox mlxsw wiki](
https://github.com/Mellanox/mlxsw/wiki/Virtual-eXtensible-Local-Area-Network-%28VXLAN%29#vxlan-routing
), the bridge MAC address needs to have the same MSB as the port mac addresses
(or for simplicity, needs to be one of the port MAC addresses) for the routing
offloads to work, but by default the bridge gets assigned the lowest MAC
address of all of its slaves (which may be a randomly generated MAC address
from something like a VxLAN device). The wiki thus recommends manually setting
the bridge address to the address of one of the ports in the bridge, so we use
the MAC address from port enp3s0np49.

```
ip link add name br0 type bridge vlan_filtering 1
ip link set dev br0 mtu 9216 up address \
    $(ip link show enp3s0np49 | grep ether | sed "s/ \+/ /g" | cut -d ' ' -f 3)
```

Add two physical ports to the bridge:

```
ip link set dev enp3s0np49 master br0 mtu 9216 up
ip link set dev enp3s0np51 master br0 mtu 9216 up
```

Change the VLAN for untagged traffic on those ports from (the default) VLAN 1
to VLAN 80.

```
bridge vlan del vid 1 dev enp3s0np49
bridge vlan del vid 1 dev enp3s0np51
bridge vlan add vid 80 dev enp3s0np49 pvid untagged
bridge vlan add vid 80 dev enp3s0np51 pvid untagged
```

It can also be useful for the switch to have a local interface attached to this
VLAN (e.g. for routing), so we create one.

```
ip link add link br0 name br0.80 type vlan id 80
bridge vlan add dev br0 vid 80 self
ip link set br0.80 up mtu 9216
ip addr add dev br0.80 192.168.80.1/24
```
