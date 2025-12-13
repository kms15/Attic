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
 - [Sysadmin-friendly ethernet switching (SN2100)](https://blog.benjojo.co.uk/post/sn2010-linux-hacking-switchdev
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
sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y linux-image-$(uname -r | cut -f1 -d+)+deb13-amd64
```

## Updating the firmware

Per the [mlxsw
wiki](https://github.com/Mellanox/mlxsw/wiki/Supported-Hardware-And-Firmware),
The minimum fully supported version of the ASIC firmware is 13.2010.1502 (at
the time this was written), and the driver will refuse to load if the version
is older than 13.2010.1006. The ASIC firmware version can be queried in
multiple ways. If the driver was able to load you can query it using devlink:

```
sudo devlink dev info
```

Example output:

```
pci/0000:03:00.0:
  driver mlxsw_spectrum
  versions:
      fixed:
        hw.revision A1
        fw.psid MT_2860113033
      running:
        fw.version 13.2010.3146
        fw 13.2010.3146
```

If the driver has not been successfully loaded, you can still query the
firmware version using the mstflint package:

```
sudo apt-get install -y mstflint # if needed
sudo mstflint -d 03:00.0 query
```

Example output:

```
Image type:            FS3
FW ISSU Version:       2
FW Version:            13.2010.3146
FW Release Date:       18.8.2022
Description:           UID                GuidsNumber
Base GUID:             900a8403004c03c0        128
Base MAC:              900a844c03c0            128
Image VSD:             N/A
Device VSD:            N/A
PSID:                  MT_2860113033
Security Attributes:   N/A
```

There are at least three different ways to [update the ASIC
firmware](https://github.com/Mellanox/mlxsw/wiki/Updating-Firmware), including
an in-driver autoupdate, the `devlink dev flash` command, and the
`mstfwmanager` command from the mstflint package. Unfortunately the in-driver
autoupdate will not work with very old versions of firmware (and still only
updates the firmware to an older-than-recommended version) and the `devlink`
firmware update approach only works once the driver has been loaded
successfully (which again is not possible with older driver versions), so
we will follow the `mstfwmanager` approach.

For reasons I do not yet understand, the debian trixie `mstflint` package
does not include the `mstfwmanager` command (but does include the man page for
it). We will thus build this tool ourselves from the upstream repository.
Before starting, we uninstall the official debian mstflint package if it is
installed.

```
sudo apt-get remove -y mstflint
```

We next install some build dependencies (note: apt-get install list probably
could be reduced):

```
sudo apt-get install -y debhelper dkms libexpat1-dev libibmad-dev libibverbs-dev \
    liblzma-dev libssl-dev pkg-config zlib1g-dev git build-essential \
    autotools-dev autoconf automake libtool dh-dkms \
    libcurl4-openssl-dev libxml2-dev
```

As with the kernel build, we will need more space than we have on the root
drive so we mount the extra partition used for the kernel build and clone the
mstflint repository there.

```
sudo mount /dev/sda2 /mnt
cd /mnt
git clone https://github.com/Mellanox/mstflint.git
cd mstflint
```

If we try to build the source as-is, we'll get an error about the version
numbers (x.x.x-1) not matching the expected version number format for a
native debian package:

```
dpkg-source: error: can't build with source format '3.0 (native)': native package version may not have a revision
```

The easiest way to fix this is to trim off the revision numbers:

```
sed -i 's/^\(mstflint ([0-9]*\.[0-9]*\.[0-9]*\)-1)/\1)/g' debian/changelog
```

We can then build and install the package, specifying that we do want to build
the firmware manager:

```
time DEB_CONFIGURE_EXTRA_FLAGS="--enable-fw-mgr" dpkg-buildpackage -uc -us
sudo dpkg -i ../mstflint{,-dkms}_*.deb
```
The firmware files can be downloaded
from the [Mellanox switchdev site](https://switchdev.mellanox.com/firmware/).
According to [comments on the servethehome forums](
https://forums.servethehome.com/index.php?threads/mellanox-switches-tips-tricks.39394/
) it's possible to brick the switch if you update older firmware in large
jumps. This might only be an issue when using the Onyx OS upgrades to update
the switch, but I decided not to experiment and updated the firmware in
multiple small jumps, including at least one of each minor build number (e.g.
X in 13.X.Y). You can apply each update and reboot between them (required) as
follows (replacing the version number as needed):

```
wget https://switchdev.mellanox.com/firmware/mlxsw_spectrum-13.2010.3146.mfa
mstfwmanager -d 03:00.0 -i mlxsw_spectrum-13.2010.3146.mfa -f -u
reboot
```

## Fan speed and noise levels

With the default settings, this is not a quiet switch.
Measuring from 3 feet away from the front of the switch, I measured ~75 dB
(roughly as loud as a vacuum cleaner - not painful, but difficult to have a
conversation over) on startup and before you have a working kernel driver,
then about 50 dB ("moderate rainfall" or "typical home", where it's
noticeable but you would not have to raise your voice to speak) once the
driver loaded. My impression is that this is fine for a closet and tolerable
(but not ideal) for an office.

To control the fan speed we can use the lm-sensors package and fancontrol.
The config file can be generated with the `pwmconfig` command, but
unfortunately when I tried it the generated file required some manual
fixes to get fancontrol to parse it. For this example we will thus
manually generate the file.

```
cat << EOF | sudo tee /etc/fancontrol
INTERVAL=10
DEVPATH=hwmon1=devices/pci0000:00/0000:00:01.2/0000:03:00.0
DEVNAME=hwmon1=mlxsw
FCTEMPS=hwmon1/pwm1=hwmon1/temp1_input
FCFANS= hwmon1/pwm1=hwmon1/fan8_input hwmon1/pwm1=hwmon1/fan7_input hwmon1/pwm1=hwmon1/fan6_input hwmon1/pwm1=hwmon1/fan5_input hwmon1/pwm1=hwmon1/fan4_input hwmon1/pwm1=hwmon1/fan3_input hwmon1/pwm1=hwmon1/fan2_input hwmon1/pwm1=hwmon1/fan1_input
MINTEMP=hwmon1/pwm1=40
MAXTEMP=hwmon1/pwm1=60
MINSTART=hwmon1/pwm1=150
MINSTOP=hwmon1/pwm1=0
EOF

sudo apt-get install -y lm-sensors fancontrol
sudo systemctl start fancontrol
sudo systemctl enable fancontrol
```

## misc setup

Set the hostname

```
sudo hostnamectl set-hostname armillaria
```

## Rapid Spanning Tree Protocol

If the network is connected in a way that there are loops (e.g. a ring),
it can cause a number of problems such as broadcast packets looping endlessly.
In LANs, that common solution to this is to automatically disable some of the
links to break any cycles that exist. This is done by electing a root bridge
and then building a spanning tree of active links from that bridge.
Traditionally this was done with the [Spanning Tree Protocol (STP)](
https://en.wikipedia.org/wiki/Spanning_Tree_Protocol#Rapid_Spanning_Tree_Protocol
), but this protocol can take 30-50 seconds to recover from a switch failure or
change in connections, so in modern LAN switches it has largely been replaced
by a newer variation of the protocol known as the
[Rapid Spanning Tree Protocol (RSTP)](
https://en.wikipedia.org/wiki/Spanning_Tree_Protocol#Rapid_Spanning_Tree_Protocol
), which can recover much more rapidly from changes (~6 seconds). There is also
a further extension of this to make better use of redundant links to distribute
traffic from multiple VLANs known as the [Multiple Spanning Tree Protocol
(MSTP)]( https://en.wikipedia.org/wiki/Multiple_Spanning_Tree_Protocol ).

Unfortunately the linux kernel only supports the older STP protocol,
recommending that other protocols to be implemented in user space. The most
popular user-space daemon for implementing RSTP and MSTP seems to be [mstpd](
https://github.com/mstpd/mstpd/tree/master ), which is used by various linux
distributions for switches such as the [DENT project]( https://dent.dev/ ) and
and [Cumulus Linux](
https://www.nvidia.com/en-us/networking/ethernet-switching/cumulus-linux/
). Note that although this project supports RSTP on a standard linux bridge,
due to (prior) limitations in the linux kernel bridge and VLAN implementations
MSTP is only supported on specialized hardware switches (but [it looks like this
may be fixed soon]( https://github.com/mstpd/mstpd/pull/150 ) ).

Note that datacenter fabrics generally do not use MSTP, RSTP, or STP, instead
using approaches such as avoiding cycles in L2 domains and distributing data
across redundant L3 links using ECMP to address many of the same problems as
the various STP protocols address.

### Building mstpd

Because mstpd is [not (yet) in the debian repositories](
https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=767013 ), we will need to
build it ourselves. As the latest official release does not include some [fixes
for fast (65Gps+) network links](
https://github.com/mstpd/mstpd/commit/20f1c93ec1b0fb9056c1770deadb88f57fb71024
), we will build from the current development branch. First we install some
prerequisites:

```
sudo apt-get install -y git build-essential autotools-dev autoconf automake libtool
```

We then clone the mstpd repository and build it

```
git clone https://github.com/mstpd/mstpd.git
cd mstpd
autoreconf --force --install
./configure --with-systemdunitdir=/usr/lib/systemd/system
make
sudo make install
```

We then enable and start the service

```
sudo systemctl enable mstpd
sudo systemctl start mstpd
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

Note that STP (and RSTP) is off by default, leading to potential broadcast
storms if you have any loops/cycles in your network. We thus enable STP on the
bridge and then force mstpd daemon to use RSTP (rather than the default of
MSTP, which is not yet considered production-ready on generic linux bridges).

```
ip link add name br0 type bridge vlan_filtering 1 stp_state 1
ip link set dev br0 mtu 9216 up address \
    $(ip link show enp3s0np49 | grep ether | sed "s/ \+/ /g" | cut -d ' ' -f 3)
mstpctl setforcevers br0 rstp
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

## RJ-45 adapter notes

It appears that the various SFP28 ports [have different power limits](
https://docs.nvidia.com/networking/display/sn2000pub/data+interfaces ), with
the following limits:

|    Ports        | Power limit |
| :-------------: | :---------: |
| 1, 2, 47, 48    |    2.5 W    |
|     3 - 46      |    1.5 W    |
| 49, 50, 55, 56  |     5 W     |
|    51 - 54      |    3.5 W    |

ports 1,2,47, and 48 able to support SFP adapters with power draws less than
2.5W and ports 3-46 only able to support adapters with power draws less than
1.5W. This limits where you can place higher power adapters like RJ-45 10G
Base-T adapters.

Of note, the [SFF-8419 standard](
file:///home/kms15/Downloads/PUBLISHED%20SFF-8419-1.PDF ) requires supporting
modules that draw <= 1 W maximum (Power Level 1 modules) and describes optionally
supporting high powered modules that draw <= 1.5W (power level 2) and <= 2 W
(power level 3) modules. Thus it seems likely that the power budgets above
were generous at the time the switch was released, and it's not surprising
that a newer RJ45 adapter drawing 2.5 W to 3 W might not be supported on this
older hardware.

Some notes on adapters tried so far:
- The ipolex ASF-10G2-T 10GBase-T adapter did not appear to work in any port.
- The Flyfiber SFP-10G-T-C 10GBase-T adapter appears to work in the 2.5W ports
  but not the 1.5W ports.
- The 10Gtek ASF-GE-T 1000Base-T adapter appears to work in any port.
