#!/bin/bash

set -xeuo pipefail

# Install some needed build dependencies and the current kernel source
sudo apt-get install -y build-essential linux-source bc kmod cpio flex \
    libncurses-dev libelf-dev libssl-dev dwarves bison debhelper libdw-dev \
    linux-source-$(uname -r | cut -d. -f1-2)

# Unzip the linux kernel source into a clean build directory
rm -rf linux-source-$(uname -r | cut -d. -f1-2)
tar xaf /usr/src/linux-source-$(uname -r | cut -d. -f1-2).tar.xz
cd linux-source-$(uname -r | cut -d. -f1-2)

# By default the debian kernel build scripts embed the actual date and time
# the kernel was built into the changelog. For reproducibility, we'll use
# the SOURCE_DATE_EPOCH variable instead if it is set.
sed -i "s/\\\$(date -R)/\
\$(date -R \${SOURCE_DATE_EPOCH:+ -d @\${SOURCE_DATE_EPOCH} } )/g" \
    scripts/package/mkdebian

# Copy the default debian config for this kernel
cp /boot/config-$(uname -r) debian.config

# Create a list of kernel config networking options we want to overide
cat <<EOF > mlxnet.config
# Enable tc-recirculation support, needed for tc offloading in many cases
CONFIG_NET_TC_SKB_EXT=y

# Enable mlx5 ipsec offloading
CONFIG_MLX5_EN_IPSEC=y

# Enable mlx5 subfunctions and VDPA support
CONFIG_MLX5_SF=y
CONFIG_MLX5_VDPA_NET=m

# Enable the mlxsw (Mellanox Spectrum ethernet switch) driver as a module
CONFIG_MLXSW_CORE=m
CONFIG_LEDS_MLXCPLD=m
EOF

# Create a list of kernel config options we want to overide for reproducible
# builds.
cat <<EOF > reproducible-build.config
# TODO: this option controls a number of security options intended to protect
# the kernel from a compromised root (e.g. not allowing root to read or write
# kernel memory). Unfortunately it currently forces module signatures, which
# aren't really compatible with the reproducible build security model (i.e.
# we're trusting the builder's private key and thus the builder and anyone
# else who has that key, which is everyone if the signatures are reproducible).
# There's an in-flight fix for this (compiling trusted module hashes into the
# kernel, enabled with the option MODULE_HASHES). Maybe we'll want to merge
# this patch set into our build in the future, but until then or until this
# reaches kernel main we'll default to trusting the local root account rather
# than having to trust the build machine. Since we aren't yet using things like
# trusted boot, dm-verity for the root filesystem, and other things that we
# would need to protect the system agains a compromised root account, we don't
# loose much from a security standpoint by disabling this for now.
CONFIG_SECURITY_LOCKDOWN_LSM=n
CONFIG_MODULE_SIG=n

# Disable debug information and module signing (for reproducibility)
CONFIG_DEBUG_INFO=n
CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT=n
CONFIG_DEBUG_INFO_BTF=n
EOF

# Merge these options with the default debian config
./scripts/kconfig/merge_config.sh debian.config mlxnet.config \
	reproducible-build.config

# Fill in any missing required options and fix any option conflicts
make olddefconfig

# For reproducibility, force any new timestamps to match the timestamp on the
# Makefile (which is set to the release tag date as part of the standard linux
# kernel release process)
export SOURCE_DATE_EPOCH=$(stat -c %Y Makefile)
export KBUILD_BUILD_TIMESTAMP="$(\
    date -u -d "@${SOURCE_DATE_EPOCH}" '+%Y-%m-%dT%H:%M:%SZ'\
)"

# For reproducibility, use a generic user and machine name rather than
# embedding the current user and hostname in the kernel.
export KBUILD_BUILD_USER="reproducible-builder"
export KBUILD_BUILD_HOST="reproducible-env"

# Build the kernel and create the debian packages for the new kernel
make clean
make -j $(nproc) bindeb-pkg
