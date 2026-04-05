#!/usr/bin/env bash
# =============================================================================
# test_stack.sh -- VXLAN-over-IPsec full-stack test, no VLAN tagging
# =============================================================================
#
# ARCHITECTURE OVERVIEW
# ---------------------
#
# This script validates the full hardware offload path for encrypted overlay
# networking WITHOUT VLAN tagging.  VLAN-based fabric separation will be
# added in a subsequent iteration once this baseline is confirmed working
# at target throughput (50+ Gbps).
#
# Three-level addressing:
#
#   Overlay:   VM IPs        (192.168.90.x)  -- tenant traffic
#   Tunnel:    tunnel IPs    (10.2.0.x / 10.3.0.x) -- per-PF VXLAN endpoints
#   Underlay:  PF IPs        (10.0.0.x / 10.0.1.x) -- IPsec SA src/dst,
#                                                       directly on PF netdev
#
# WHY NO VLAN IN THIS VERSION
# ---------------------------
# The NIC's IPsec packet offload engine is registered on the PF netdev.
# VLAN subinterfaces are a kernel software abstraction -- the NIC hardware
# has no mechanism to perform IPsec packet offload on a VLAN subif.
# Attempting offload on a VLAN subif returns RTNETLINK Invalid argument.
# Routing IPsec traffic directly via the PF resolves this.
#
# ACTIVE-ACTIVE DUAL-PF DESIGN
# ----------------------------
# Each PF has its own unique pair of tunnel IPs and its own SA pair.
# The SA src/dst (tunnel IPs) uniquely identifies each SA without if_id,
# enabling full hardware offload in BOTH directions (inbound and outbound).
# Both SA pairs are installed and offloaded simultaneously.
#
# On-wire format (PF0 path, transport mode):
#
#   [Ethernet | IP (10.2.0.x) | ESP | UDP:4789 | VXLAN (VNI=100) | Eth | payload]
#
# Interface chain (egress from VM):
#
#   VM (ns0, VF enp3s0f0v0)
#     |
#   VF representor (enp3s0f0r0)  <-- TC rules here
#     |
#     +-- TC prio 10: untracked   -> ct
#     +-- TC prio 20: +trk+new    -> ct commit
#     +-- TC prio 30: +trk+est    -> tunnel_key(TUN0) + mirred -> vxlan_tun0
#     \-- new flows               -> bridge
#     |
#   br_ov0 (bridge)
#     |
#     +-- vxlan_tun0 (local=10.2.0.1, remote=10.2.0.2, VNI=100)
#     |     xfrm OUTPUT hook: src=10.2.0.1 matches policy -> PF0 SA
#     |     transport mode: ESP wraps UDP+VXLAN+payload in-place
#     |     post-xfrm: dst=10.2.0.2, route via enp3s0f0np0 directly
#     |
#     \-- vxlan_tun1 (local=10.3.0.1, remote=10.3.0.2, VNI=101)
#           xfrm OUTPUT hook: src=10.3.0.1 matches policy -> PF1 SA
#           post-xfrm: dst=10.3.0.2, route via enp3s0f1np1 directly
#
# ROUTING LOOP ANALYSIS (transport mode, no VLAN)
# ------------------------------------------------
# Pre-encryption:  dst=10.2.0.2 -> route via enp3s0f0np0 (direct, no xfrmi)
# xfrm encrypts:   transport mode, no new outer IP added, dst stays 10.2.0.2
# Post-encryption: dst=10.2.0.2 -> same route via enp3s0f0np0
#
# This could loop, BUT: after xfrm marks the skb as encrypted (sets a
# completed-SA flag), the OUTPUT hook does not re-apply xfrm to it.
# The kernel's xfrm_output path checks XFRM_STATE_OUTPUT_MASK on the skb
# and skips the policy lookup for already-transformed packets.
# No routing loop occurs.
#
# HARDWARE OFFLOAD PREREQUISITES
# ------------------------------
# 1. DMFS must be set on both PFs before switchdev activation (Step 2).
#    SMFS (default) does not support xfrm packet offload.
# 2. esp4_offload.ko must be loaded.
# 3. SA must have non-zero reqid matching the policy tmpl reqid.
#    mlx5 requires reqid to anchor the SA in its flow table.
# 4. SA offload device must be the PF netdev, not a VLAN subif.
#
# =============================================================================
# USAGE
#   chmod +x test_stack.sh
#   sudo ./test_stack.sh 1       # Server 1 -- VM gets 192.168.90.2
#   sudo ./test_stack.sh 2       # Server 2 -- VM gets 192.168.90.3
#
# TEST SEQUENCE
#   Underlay:
#     ping -c2 -I 10.0.0.1 10.0.0.2    # direct PF0 underlay
#     ping -c2 -I 10.2.0.1 10.2.0.2    # PF0 IPsec tunnel
#     ping -c2 -I 10.3.0.1 10.3.0.2    # PF1 IPsec tunnel
#   Overlay:
#     Server 2: ip netns exec ns0 iperf3 -s
#     Server 1: ip netns exec ns0 iperf3 --bidi -P 8 -c 192.168.90.3
#
# OFFLOAD VERIFICATION
#   ip xfrm state        # all 4 SAs should show 'offload packet'
#   ip -s xfrm state     # byte/packet counters should increment during traffic
#   ethtool -S enp3s0f0np0 | grep -iE 'ipsec|esp'
#   ethtool -S enp3s0f1np1 | grep -iE 'ipsec|esp'
#   grep -v ' 0$' /proc/net/xfrm_stat   # should stay near 0 if offloaded
#   tc filter show dev enp3s0f0r0 ingress  # 'hw' on prio 30 = TC offloaded
# =============================================================================

set -euo pipefail

###############################################################################
# SECTION 1: ARGUMENTS AND INTERFACE NAMES
###############################################################################

SERVER_ID="${1:?Usage: $0 <1|2>}"

PF0="enp3s0f0np0"
PF1="enp3s0f1np1"
VF0="enp3s0f1v0"
VF0_REP="enp3s0f1r0"

# Tunnel dummy interfaces -- one per PF path.
# These hold the tunnel source IPs used as VXLAN local and SA src/dst.
TUN0_DUMMY="tun0"
TUN1_DUMMY="tun1"

# VXLAN devices -- one per PF path.
VXLAN_TUN0="vxlan_tun0"
VXLAN_TUN1="vxlan_tun1"

BRIDGE_DEV="br_ov0"
NS="ns0"

###############################################################################
# SECTION 2: CONSTANTS
###############################################################################

# Each VXLAN device needs a unique VNI.  The kernel shares one UDP socket
# per port (INADDR_ANY:4789) and dispatches by VNI.  Two devices with the
# same VNI on one socket are rejected with "VNI already exists".
VNI_TUN0=100
VNI_TUN1=101
VXLAN_PORT=4789

# MTU: no VLAN overhead in this version.
# Transport mode ESP overhead: ESP hdr(8) + IV(8) + ICV(16) + pad(<=4) = ~36B
# VXLAN overhead: UDP(8) + VXLAN(8) + inner Eth(14) = 30B
# Total overhead above inner payload: ~66B
# 9000 overlay MTU is safe with 9216 PF MTU.
PF_MTU=9216
OVERLAY_MTU=9000

###############################################################################
# SECTION 3: IPsec KEYS AND SPIs
#
# AES-128-GCM (rfc4106): 16-byte key + 4-byte GCM salt = 40 hex chars
# ICV: 128-bit (16-byte auth tag)
#
# Transport mode: SA src/dst = tunnel IPs (the actual packet src/dst).
# No separate outer IP header -- the tunnel IP IS the outer IP.
#
# reqid: must be non-zero and match between SA and policy tmpl.
# mlx5 uses reqid to anchor the SA in its hardware flow table.
#
# !! TEST KEYS ONLY -- use strongSwan + IKEv2 for production !!
###############################################################################

K_T0_12="0xa0b1c2d3e4f506172839aabbccddeeff01020304"
K_T0_21="0xb1c2d3e4f506172839aabbccddeeff0a01020304"
K_T1_12="0xc2d3e4f506172839aabbccddeeff0ab101020304"
K_T1_21="0xd3e4f506172839aabbccddeeff0ab1c201020304"

SPI_T0_12=0x00001001
SPI_T0_21=0x00001002
SPI_T1_12=0x00001003
SPI_T1_21=0x00001004

REQID_T0_OUT=10
REQID_T0_IN=11
REQID_T1_OUT=20
REQID_T1_IN=21

###############################################################################
# SECTION 4: SERVER-SPECIFIC ADDRESSING
###############################################################################

case "$SERVER_ID" in
1)
    # PF IPs: direct underlay addresses on each PF netdev (no VLAN)
    PF0_IP="10.0.0.1/30"  ;  PF0_PEER="10.0.0.2"
    PF1_IP="10.0.1.1/30"  ;  PF1_PEER="10.0.1.2"

    # Tunnel IPs: per-PF VXLAN local/remote, also the IPsec SA src/dst
    TUN0_LOCAL="10.2.0.1"  ;  TUN0_REMOTE="10.2.0.2"
    TUN1_LOCAL="10.3.0.1"  ;  TUN1_REMOTE="10.3.0.2"

    # Overlay
    VM_IP="192.168.90.2/24"
    BRIDGE_IP="192.168.90.1/24"
    VM_GW="192.168.90.1"

    # SA keys/SPIs: S1 sends with _12, receives with _21
    T0_SPI_OUT=$SPI_T0_12  ;  T0_KEY_OUT=$K_T0_12
    T0_SPI_IN=$SPI_T0_21   ;  T0_KEY_IN=$K_T0_21
    T1_SPI_OUT=$SPI_T1_12  ;  T1_KEY_OUT=$K_T1_12
    T1_SPI_IN=$SPI_T1_21   ;  T1_KEY_IN=$K_T1_21
    ;;
2)
    PF0_IP="10.0.0.2/30"  ;  PF0_PEER="10.0.0.1"
    PF1_IP="10.0.1.2/30"  ;  PF1_PEER="10.0.1.1"

    TUN0_LOCAL="10.2.0.2"  ;  TUN0_REMOTE="10.2.0.1"
    TUN1_LOCAL="10.3.0.2"  ;  TUN1_REMOTE="10.3.0.1"

    VM_IP="192.168.90.3/24"
    BRIDGE_IP="192.168.90.1/24"
    VM_GW="192.168.90.1"

    # S2 sends with _21, receives with _12
    T0_SPI_OUT=$SPI_T0_21  ;  T0_KEY_OUT=$K_T0_21
    T0_SPI_IN=$SPI_T0_12   ;  T0_KEY_IN=$K_T0_12
    T1_SPI_OUT=$SPI_T1_21  ;  T1_KEY_OUT=$K_T1_21
    T1_SPI_IN=$SPI_T1_12   ;  T1_KEY_IN=$K_T1_12
    ;;
*)
    echo "Error: SERVER_ID must be 1 or 2" >&2 ; exit 1 ;;
esac

PF0_LOCAL_IP="${PF0_IP%/*}"
PF1_LOCAL_IP="${PF1_IP%/*}"

###############################################################################
# HELPERS
###############################################################################

log()  { echo -e "\n\033[1;32m>>> $*\033[0m"; }
warn() { echo -e "\033[1;33mWARN: $*\033[0m" >&2; }

# ---------------------------------------------------------------------------
# xfrm_attempt <label> <tmpfile> <cmd...>
# Runs cmd, captures stderr.  On failure:
#   - Silently returns 1 for expected capability-probe failures
#   - Prints the error and returns 1 for unexpected errors
# This allows fallback chains without hiding real problems.
# ---------------------------------------------------------------------------
xfrm_attempt() {
    local label="$1" tmpfile="$2"; shift 2
    local err
    if "$@" 2>"$tmpfile"; then
        return 0
    fi
    err=$(cat "$tmpfile")
    case "$err" in
        *"not supported"*|*"No such"*|*"EOPNOTSUPP"*|*"Invalid argument"*|\
        *"unknown"*|*"offload mode"*)
            ;;
        *)
            [ -n "$err" ] && warn "($label): $err"
            ;;
    esac
    return 1
}

# ---------------------------------------------------------------------------
# xfrm_state_add <dev> <dir in|out> <label> [ip xfrm state add args]
#
# Tries hardware offload in order: packet -> crypto -> old-style -> software.
# All SA args are passed in "$@"; no if_id (SA src/dst is unique per PF path).
# 'dir' is appended to the offload clause as required by both new and old
# iproute2 syntax in the tested environment.
# The final software fallback never suppresses stderr.
# ---------------------------------------------------------------------------
xfrm_state_add() {
    local dev="$1" dir="$2" label="$3"; shift 3
    local tmpfile
    tmpfile=$(mktemp /tmp/xfrm_sa.XXXXXX)
    if xfrm_attempt "$label/packet" "$tmpfile" \
            ip xfrm state add "$@" offload packet dev "$dev" dir "$dir"; then
        echo "  SA: full PACKET offload on $dev ($label)"
    elif xfrm_attempt "$label/crypto" "$tmpfile" \
            ip xfrm state add "$@" offload crypto dev "$dev" dir "$dir"; then
        warn "Packet offload unavailable -- CRYPTO offload ($label)"
    elif xfrm_attempt "$label/old-style" "$tmpfile" \
            ip xfrm state add "$@" offload dev "$dev" dir "$dir"; then
        warn "New offload syntax unavailable -- old-style offload ($label)"
    else
        warn "HW offload unavailable -- software xfrm ($label)"
        ip xfrm state add "$@"
    fi
    rm -f "$tmpfile"
}

# ---------------------------------------------------------------------------
# xfrm_policy_add <dev> <dir in|out> [ip xfrm policy add args]
#
# "$@" must NOT contain 'dir' -- the helper injects it exactly once as the
# main policy direction arg.  The offload clause does not repeat 'dir' for
# the new 'packet' syntax; the old-style fallback does.
# ---------------------------------------------------------------------------
xfrm_policy_add() {
    local dev="$1" dir="$2"; shift 2
    local tmpfile
    tmpfile=$(mktemp /tmp/xfrm_pol.XXXXXX)
    if xfrm_attempt "$dir/packet" "$tmpfile" \
            ip xfrm policy add "$@" dir "$dir" \
                offload packet dev "$dev"; then
        echo "  Policy: PACKET offload on $dev (dir=$dir)"
    elif xfrm_attempt "$dir/old-style" "$tmpfile" \
            ip xfrm policy add "$@" dir "$dir" \
                offload dev "$dev" dir "$dir"; then
        warn "New policy offload syntax unavailable -- old-style (dir=$dir)"
    else
        warn "Policy offload unavailable on $dev dir=$dir -- software"
        ip xfrm policy add "$@" dir "$dir"
    fi
    rm -f "$tmpfile"
}

# ---------------------------------------------------------------------------
# seed_neighbor <ip> <iface>
# Pre-seeds a permanent ARP entry on <iface> for <ip>.
# Post-xfrm transport mode packets route via the PF connected route and
# need a valid neighbour entry for the peer IP.
# ---------------------------------------------------------------------------
seed_neighbor() {
    local ip="$1" iface="$2"
    ping -c1 -W1 -I "$iface" "$ip" > /dev/null 2>&1 || true
    local mac
    mac=$(ip neigh show dev "$iface" 2>/dev/null \
          | awk -v ip="$ip" '$1==ip && $4=="lladdr" {print $5; exit}')
    if [ -n "$mac" ]; then
        ip neigh replace "$ip" dev "$iface" lladdr "$mac" nud permanent
        echo "  Neighbor $ip on $iface: $mac (permanent)"
    else
        warn "Could not resolve $ip on $iface -- ARP may fail"
        echo "  Manual fix: ip neigh replace $ip dev $iface lladdr <MAC> nud permanent"
    fi
}

###############################################################################
# STEP 0: CLEANUP
###############################################################################
log "STEP 0: Cleanup"

ip netns del "$NS"            2>/dev/null || true
ip link del  "$BRIDGE_DEV"    2>/dev/null || true
ip link del  "$VXLAN_TUN0"    2>/dev/null || true
ip link del  "$VXLAN_TUN1"    2>/dev/null || true
ip xfrm state  flush          2>/dev/null || true
ip xfrm policy flush          2>/dev/null || true
ip link del  "$TUN0_DUMMY"    2>/dev/null || true
ip link del  "$TUN1_DUMMY"    2>/dev/null || true
# Remove PF IP addresses if previously set (idempotent re-run)
ip addr del "$PF0_IP" dev "$PF0" 2>/dev/null || true
ip addr del "$PF1_IP" dev "$PF1" 2>/dev/null || true
tc qdisc del dev "$VF0_REP"    clsact 2>/dev/null || true
tc qdisc del dev "$VXLAN_TUN0" clsact 2>/dev/null || true
iptables -D FORWARD -i "$BRIDGE_DEV" -o "$BRIDGE_DEV" -j ACCEPT 2>/dev/null || true

###############################################################################
# STEP 1: KERNEL MODULES AND SYSCTLS
###############################################################################
log "STEP 1: Kernel modules and sysctls"

# esp4_offload: registers xfrm TX/RX offload hooks with the kernel.
# Without it 'offload packet' SA installation fails even if the NIC supports it.
for mod in vxlan esp4 esp4_offload nf_conntrack; do
    modprobe "$mod" 2>/dev/null || warn "Could not load $mod (may be built-in)"
done

sysctl -qw net.ipv4.ip_forward=1
sysctl -qw net.ipv4.conf.all.forwarding=1
sysctl -qw net.ipv4.conf.all.rp_filter=0
sysctl -qw net.netfilter.nf_conntrack_max=524288 2>/dev/null || true

# Disable bridge netfilter to prevent iptables FORWARD rules from dropping
# bridged frames (common with Docker default DROP policy).
sysctl -qw net.bridge.bridge-nf-call-iptables=0  2>/dev/null || true
sysctl -qw net.bridge.bridge-nf-call-ip6tables=0 2>/dev/null || true
sysctl -qw net.bridge.bridge-nf-call-arptables=0 2>/dev/null || true

###############################################################################
# STEP 2: SR-IOV, DMFS, AND SWITCHDEV MODE
#
# Required sequence:
#   a. Unbind VF            mlx5 requires this before eswitch mode change
#   b. Both PFs to legacy   devlink requires legacy before flow_steering_mode
#   c. DMFS on both PFs     required for 'offload packet' SA installation
#   d. PFs to switchdev     exposes VF0 representor enp3s0f0r0
#   e. Rebind VF
#
# PF1 stays in legacy eswitch mode (used only as second underlay path).
# DMFS is set on PF1 because its IPsec SAs use PF1's NIC flow tables
# regardless of eswitch mode.
###############################################################################
log "STEP 2: SR-IOV, DMFS, and switchdev"

ip link set "$PF0" up
ip link set "$PF1" up

CURRENT_VFS=$(cat /sys/class/net/"$PF1"/device/sriov_numvfs 2>/dev/null || echo 0)
if [ "$CURRENT_VFS" -lt 1 ]; then
    echo 0 > /sys/class/net/"$PF1"/device/sriov_numvfs 2>/dev/null || true
    sleep 0.3
    echo 1 > /sys/class/net/"$PF1"/device/sriov_numvfs
    sleep 1
fi

PCI0=$(ethtool -i "$PF0" 2>/dev/null | awk '/bus-info/{print $2}')
PCI1=$(ethtool -i "$PF1" 2>/dev/null | awk '/bus-info/{print $2}')
echo "  PF0 PCI: $PCI0"
echo "  PF1 PCI: $PCI1"

# a. Unbind VF
VF0_PCI=$(readlink -f /sys/class/net/"$PF1"/device/virtfn0 2>/dev/null \
          | xargs basename 2>/dev/null || true)
if [ -n "$VF0_PCI" ] && [ -d "/sys/bus/pci/devices/$VF0_PCI/driver" ]; then
    echo "  Unbinding VF $VF0_PCI"
    echo "$VF0_PCI" > /sys/bus/pci/devices/"$VF0_PCI"/driver/unbind 2>/dev/null || true
    sleep 0.3
fi

# b. Both PFs to legacy
devlink dev eswitch set pci/"$PCI0" mode legacy 2>/dev/null || true
devlink dev eswitch set pci/"$PCI1" mode legacy 2>/dev/null || true
sleep 0.2

# c. DMFS on both PFs
for PCI in "$PCI0" "$PCI1"; do
    if devlink dev param set pci/"$PCI" \
            name flow_steering_mode value dmfs cmode runtime 2>/dev/null; then
        echo "  DMFS enabled on pci/$PCI"
    else
        warn "Could not set DMFS on pci/$PCI -- packet offload may not work"
        devlink dev param show pci/"$PCI" name flow_steering_mode 2>/dev/null || true
    fi
done
sleep 0.2

# d. PFs to switchdev
devlink dev eswitch set pci/"$PCI0" mode switchdev
echo "  Switchdev enabled on pci/$PCI0"
devlink dev eswitch set pci/"$PCI1" mode switchdev
echo "  Switchdev enabled on pci/$PCI1"

sudo devlink dev param set pci/"$PCI0" name esw_multiport value true cmode runtime
sudo devlink dev param set pci/"$PCI1" name esw_multiport value true cmode runtime

# e. Rebind VF
if [ -n "$VF0_PCI" ]; then
    echo "$VF0_PCI" > /sys/bus/pci/drivers/mlx5_core/bind 2>/dev/null || true
    sleep 0.5
fi

ip link set "$PF0" mtu "$PF_MTU"
ip link set "$PF1" mtu "$PF_MTU"
ip link set "$VF0"     up 2>/dev/null || warn "VF0 not yet visible"
ip link set "$VF0_REP" mtu "$OVERLAY_MTU"
ip link set "$VF0_REP" up

###############################################################################
# STEP 3: PF IP ADDRESSES
#
# Assign underlay IPs directly to the PF netdevs (no VLAN subifs).
# These are the peer addresses for ARP and the next-hop for tunnel routes.
# The tunnel IPs (Step 5) are the SA src/dst and VXLAN local addresses.
###############################################################################
log "STEP 3: PF IP addresses"

ip addr add "$PF0_IP" dev "$PF0"
ip addr add "$PF1_IP" dev "$PF1"

sysctl -qw "net.ipv4.conf.${PF0}.rp_filter=0" 2>/dev/null || true
sysctl -qw "net.ipv4.conf.${PF1}.rp_filter=0" 2>/dev/null || true

ip link set "$PF0" up
ip link set "$PF1" up

echo "  PF0: $PF0_IP"
echo "  PF1: $PF1_IP"

###############################################################################
# STEP 4: PRE-SEED NEIGHBOUR ENTRIES ON PF NETDEVS
#
# Post-xfrm transport mode packets have dst=TUN_REMOTE and route via the
# PF connected subnet (e.g. 10.0.0.0/30 on enp3s0f0np0).  The kernel needs
# a valid ARP entry for the peer PF IP (10.0.0.2) to deliver the ESP frame.
# Pre-seeding makes entries permanent to avoid silent drops during testing.
###############################################################################
log "STEP 4: Pre-seed neighbour entries on PF netdevs"

seed_neighbor "$PF0_PEER" "$PF0"
seed_neighbor "$PF1_PEER" "$PF1"

###############################################################################
# STEP 5: TUNNEL DUMMY INTERFACES
#
# Each dummy holds the local tunnel IP for one PF path.
# These IPs serve three roles simultaneously:
#   1. VXLAN 'local' address (outer VXLAN src IP)
#   2. IPsec SA src (outbound) / dst (inbound)
#   3. xfrm policy selector src (outbound) / dst (inbound)
#
# Having unique IPs per PF makes each SA uniquely identifiable by src/dst
# without requiring if_id, enabling full hardware offload in both directions.
###############################################################################
log "STEP 5: Tunnel dummy interfaces"

ip link add "$TUN0_DUMMY" type dummy
ip addr add "${TUN0_LOCAL}/32" dev "$TUN0_DUMMY"
ip link set "$TUN0_DUMMY" up
echo "  $TUN0_DUMMY: $TUN0_LOCAL (PF0 path)"

ip link add "$TUN1_DUMMY" type dummy
ip addr add "${TUN1_LOCAL}/32" dev "$TUN1_DUMMY"
ip link set "$TUN1_DUMMY" up
echo "  $TUN1_DUMMY: $TUN1_LOCAL (PF1 path)"

###############################################################################
# STEP 6: ROUTES TO REMOTE TUNNEL IPs
#
# Each tunnel IP is routed exclusively via its designated PF netdev.
# This pins each SA to a specific physical path and prevents cross-path
# SA selection.
#
# 'src TUN_LOCAL': ensures the kernel selects the tunnel IP as source so
# the xfrm policy selector (src=TUN_LOCAL/32) matches.
#
# No routing loop: after xfrm encrypts in transport mode the skb is marked
# as already-transformed and the OUTPUT hook skips re-applying xfrm.
###############################################################################
log "STEP 6: Routes to remote tunnel IPs"

ip route add "${TUN0_REMOTE}/32" via "$PF0_PEER" dev "$PF0" src "$TUN0_LOCAL"
ip route add "${TUN1_REMOTE}/32" via "$PF1_PEER" dev "$PF1" src "$TUN1_LOCAL"

echo "  $TUN0_REMOTE via $PF0 src $TUN0_LOCAL (PF0)"
echo "  $TUN1_REMOTE via $PF1 src $TUN1_LOCAL (PF1)"

###############################################################################
# STEP 7: xfrm SECURITY ASSOCIATIONS
#
# Transport mode: SA src/dst are the tunnel IPs (the actual packet src/dst).
# No outer IP header is added -- the tunnel IP IS the packet's IP header.
#
# SA offload bound to the PF netdev (not a VLAN subif).  The NIC's IPsec
# engine is registered at the PF level; VLAN subifs are not supported as
# offload devices (returns RTNETLINK Invalid argument).
#
# reqid must be non-zero and match the policy tmpl reqid (Step 8).
#
# All four SAs should show 'offload packet' in 'ip xfrm state' output.
# If any show 'offload crypto' the xfrm_attempt helper will print a warning
# with the actual error from the driver so it can be investigated.
###############################################################################
log "STEP 7: xfrm states (transport mode, offload on PF)"

echo "  TUN0 out: $TUN0_LOCAL -> $TUN0_REMOTE  SPI=$(printf '0x%08x' $T0_SPI_OUT)"
xfrm_state_add "$PF0" out "TUN0-out" \
    src "$TUN0_LOCAL" dst "$TUN0_REMOTE" \
    proto esp spi "$T0_SPI_OUT" reqid $REQID_T0_OUT \
    aead 'rfc4106(gcm(aes))' "$T0_KEY_OUT" 128 \
    mode transport

echo "  TUN0 in:  $TUN0_REMOTE -> $TUN0_LOCAL  SPI=$(printf '0x%08x' $T0_SPI_IN)"
xfrm_state_add "$PF0" in "TUN0-in" \
    src "$TUN0_REMOTE" dst "$TUN0_LOCAL" \
    proto esp spi "$T0_SPI_IN" reqid $REQID_T0_IN \
    aead 'rfc4106(gcm(aes))' "$T0_KEY_IN" 128 \
    mode transport

echo "  TUN1 out: $TUN1_LOCAL -> $TUN1_REMOTE  SPI=$(printf '0x%08x' $T1_SPI_OUT)"
xfrm_state_add "$PF1" out "TUN1-out" \
    src "$TUN1_LOCAL" dst "$TUN1_REMOTE" \
    proto esp spi "$T1_SPI_OUT" reqid $REQID_T1_OUT \
    aead 'rfc4106(gcm(aes))' "$T1_KEY_OUT" 128 \
    mode transport

echo "  TUN1 in:  $TUN1_REMOTE -> $TUN1_LOCAL  SPI=$(printf '0x%08x' $T1_SPI_IN)"
xfrm_state_add "$PF1" in "TUN1-in" \
    src "$TUN1_REMOTE" dst "$TUN1_LOCAL" \
    proto esp spi "$T1_SPI_IN" reqid $REQID_T1_IN \
    aead 'rfc4106(gcm(aes))' "$T1_KEY_IN" 128 \
    mode transport

###############################################################################
# STEP 8: xfrm POLICIES
#
# Policy selectors: tunnel IPs (the actual packet src/dst in transport mode).
# Template: same tunnel IPs as src/dst, mode transport.
# No separate outer IP -- transport mode has no tunnel IP distinction.
#
# ASYMMETRY: each server's outbound policy src must be its own tunnel IP.
# LOCAL/REMOTE variables are already set correctly per server in Section 4.
#
# Call sites do NOT include 'dir' -- xfrm_policy_add injects it.
###############################################################################
log "STEP 8: xfrm policies"

install_policy_pair() {
    local pf="$1" tun_local="$2" tun_remote="$3" reqid_out="$4" reqid_in="$5"

    xfrm_policy_add "$pf" out \
        src "${tun_local}/32" dst "${tun_remote}/32" \
        priority 100 \
        tmpl src "$tun_local" dst "$tun_remote" \
            proto esp mode transport reqid "$reqid_out"

    xfrm_policy_add "$pf" in \
        src "${tun_remote}/32" dst "${tun_local}/32" \
        priority 100 \
        tmpl src "$tun_remote" dst "$tun_local" \
            proto esp mode transport reqid "$reqid_in"

    echo "  Policies: $tun_local <-> $tun_remote on $pf"
}

install_policy_pair "$PF0" "$TUN0_LOCAL" "$TUN0_REMOTE" $REQID_T0_OUT $REQID_T0_IN
install_policy_pair "$PF1" "$TUN1_LOCAL" "$TUN1_REMOTE" $REQID_T1_OUT $REQID_T1_IN

###############################################################################
# STEP 9: VXLAN DEVICES
#
# One VXLAN device per PF path.  Each uses its tunnel IP as local address.
# VXLAN outer src = tunnel IP -> xfrm OUTPUT hook matches policy -> SA encrypts.
#
# On inbound: NIC decrypts ESP by SPI lookup, inner packet has dst=TUN_LOCAL,
# kernel delivers to local stack, VXLAN socket matches on (dst IP, VNI, port).
#
# Unique VNIs required: kernel shares one UDP socket per port and dispatches
# by VNI.  Two devices with the same VNI on the same socket are rejected.
###############################################################################
log "STEP 9: VXLAN devices"

ip link add "$VXLAN_TUN0" type vxlan \
    id $VNI_TUN0 \
    local  "$TUN0_LOCAL" \
    remote "$TUN0_REMOTE" \
    dstport $VXLAN_PORT \
    learning \
    ageing 300 \
    noudpcsum

ip link add "$VXLAN_TUN1" type vxlan \
    id $VNI_TUN1 \
    local  "$TUN1_LOCAL" \
    remote "$TUN1_REMOTE" \
    dstport $VXLAN_PORT \
    learning \
    ageing 300 \
    noudpcsum

ip link set "$VXLAN_TUN0" mtu $OVERLAY_MTU
ip link set "$VXLAN_TUN1" mtu $OVERLAY_MTU
ip link set "$VXLAN_TUN0" up
ip link set "$VXLAN_TUN1" up

echo "  $VXLAN_TUN0: local=$TUN0_LOCAL remote=$TUN0_REMOTE VNI=$VNI_TUN0"
echo "  $VXLAN_TUN1: local=$TUN1_LOCAL remote=$TUN1_REMOTE VNI=$VNI_TUN1"

###############################################################################
# STEP 10: OVERLAY BRIDGE
###############################################################################
log "STEP 10: Overlay bridge $BRIDGE_DEV"

ip link add "$BRIDGE_DEV" type bridge
ip link set "$BRIDGE_DEV" type bridge \
    stp_state   0 \
    ageing_time 60000 \
    vlan_filtering 0

ip link set "$VF0_REP"    master "$BRIDGE_DEV"
ip link set "$VXLAN_TUN0" master "$BRIDGE_DEV"
# vxlan_tun1 is intentionally NOT added to the bridge.
# Two VXLAN devices pointing to the same remote on the same bridge create a
# broadcast storm: the bridge floods unknown/multicast frames to all ports,
# each VXLAN device delivers a copy to the remote bridge, which floods again.
# vxlan_tun1 is kept for independent PF1 SA validation via direct tunnel
# pings (ping -I 10.3.0.1 10.3.0.2) but does not carry overlay traffic.
# Active-active ECMP across both PFs requires a loop-prevention mechanism
# (e.g. per-flow TC redirect, EVPN split-horizon, or ESI-based filtering)
# before both VXLAN devices can be bridged simultaneously.

ip addr add "$BRIDGE_IP" dev "$BRIDGE_DEV"
ip link set "$BRIDGE_DEV" mtu $OVERLAY_MTU
ip link set "$BRIDGE_DEV" up

# Belt-and-suspenders: permit bridge-internal forwarding in iptables.
# Needed when bridge-nf-call-iptables=1 with a DROP FORWARD policy (Docker).
iptables -I FORWARD 1 -i "$BRIDGE_DEV" -o "$BRIDGE_DEV" -j ACCEPT 2>/dev/null || \
    warn "Could not insert iptables FORWARD rule -- bridged traffic may be dropped"

###############################################################################
# STEP 11: VM NETWORK NAMESPACE
###############################################################################
log "STEP 11: Network namespace $NS (VM at $VM_IP)"

ip netns add "$NS"
ip link set "$VF0" netns "$NS"

ip netns exec "$NS" ip link set lo     up
ip netns exec "$NS" ip link set "$VF0" up
ip netns exec "$NS" ip link set "$VF0" mtu $OVERLAY_MTU
ip netns exec "$NS" ip addr add "$VM_IP" dev "$VF0"
ip netns exec "$NS" ip route add default via "$VM_GW"

###############################################################################
# STEP 12: TC RULES FOR HARDWARE OFFLOAD
#
# Three-priority conntrack state machine on VF0_REP ingress.
# Prio 30 is the hardware offload candidate for established flows.
#
# This script uses vxlan_tun0 (PF0 path) for all TC-offloaded flows.
# For production active-active ECMP across both PFs, replace prio 30 with
# a TC hash chain distributing flows across vxlan_tun0 and vxlan_tun1.
#
# Transparency: removing these rules falls back to the bridge software path.
###############################################################################
log "STEP 12: TC rules for hardware offload"

# TX PATH -- ingress on VF representor (VM -> wire)
# -------------------------------------------------
# Matches IPv4 non-fragment frames from the VM and redirects them directly
# to the VXLAN device with tunnel metadata set.  Bypasses the bridge for
# the forward path.  mlx5 offloads this as a single FTE in the e-switch FDB.
#
# 'ip_flags nofrag': restricts the rule to non-fragmented frames, which is
# the expected case for all VM traffic and is required by mlx5 for FTE
# construction with tunnel_key actions.
#
# 'nofrag ttl 64' in the tunnel_key set clause: these parameters complete
# the VXLAN outer header that the NIC constructs in hardware.  Without them
# the driver may not be able to build a valid FTE for the encap action.
#
# ARP and non-IP frames do not match 'protocol ip' and fall through to the
# bridge for neighbour discovery and MAC learning.
tc qdisc add dev "$VF0_REP" clsact

tc filter add dev "$VF0_REP" ingress \
    protocol ip prio 10 flower \
    ip_flags nofrag \
    action tunnel_key set \
        src_ip   "$TUN0_LOCAL" \
        dst_ip   "$TUN0_REMOTE" \
        id       $VNI_TUN0 \
        dst_port $VXLAN_PORT \
        nocsum \
        nofrag \
        ttl 64 \
    action mirred egress redirect dev "$VXLAN_TUN0"

# RX PATH -- ingress on VXLAN device (wire -> VM)
# ------------------------------------------------
# Matches frames arriving on vxlan_tun0 using enc_ (encapsulation) match
# parameters.  The enc_ parameters identify the specific VXLAN tunnel and
# are required for mlx5 to construct a valid FTE for the return path.
# Without enc_ parameters the driver cannot create a specific enough match
# and the rule stays in software (no in_hw flag).
#
# 'tunnel_key unset': strips the VXLAN tunnel metadata from the skb before
# redirecting to the VF representor, so the VM receives a plain Ethernet
# frame rather than a VXLAN-encapsulated one.
#
# This mirrors the OVS return path rule which shows in_hw_count 2 on
# ConnectX-6 Dx hardware, confirming the driver supports this combination.
tc qdisc add dev "$VXLAN_TUN0" clsact

tc filter add dev "$VXLAN_TUN0" ingress \
    protocol ip prio 10 flower \
    enc_dst_ip   "$TUN0_LOCAL" \
    enc_src_ip   "$TUN0_REMOTE" \
    enc_key_id   $VNI_TUN0 \
    enc_dst_port $VXLAN_PORT \
    ip_flags nofrag \
    action tunnel_key unset \
    action mirred egress redirect dev "$VF0_REP"

###############################################################################
# VERIFICATION SUMMARY
###############################################################################
log "Verification"

echo ""
echo "-- PF addresses -----------------------------------------------------------"
ip -br addr show "$PF0" | head -1 || echo "  MISSING: $PF0"
ip -br addr show "$PF1" | head -1 || echo "  MISSING: $PF1"

echo ""
echo "-- Permanent neighbours on PF netdevs -------------------------------------"
ip neigh show dev "$PF0" | grep -v "^$" || echo "  (none on $PF0)"
ip neigh show dev "$PF1" | grep -v "^$" || echo "  (none on $PF1)"

echo ""
echo "-- Tunnel dummy interfaces ------------------------------------------------"
ip -br addr show "$TUN0_DUMMY" || echo "  MISSING: $TUN0_DUMMY"
ip -br addr show "$TUN1_DUMMY" || echo "  MISSING: $TUN1_DUMMY"

echo ""
echo "-- Routes to remote tunnel IPs --------------------------------------------"
ip route show "${TUN0_REMOTE}/32" || echo "  NONE for $TUN0_REMOTE"
ip route show "${TUN1_REMOTE}/32" || echo "  NONE for $TUN1_REMOTE"

echo ""
echo "-- xfrm SAs (4 expected, all transport mode, all should show 'offload packet')"
ip xfrm state | grep -E "^src|mode|spi|offload" || echo "  NONE"

echo ""
echo "-- xfrm policies (4 expected) ---------------------------------------------"
ip xfrm policy | grep -E "^src|dir|tmpl|offload" || echo "  NONE"

echo ""
echo "-- Bridge ports (VF0_REP + vxlan_tun0 only -- vxlan_tun1 not bridged) ----"
bridge link show 2>/dev/null \
    | grep -E "$VF0_REP|$VXLAN_TUN0" || echo "  (none)"

echo ""
echo "-- Namespace $NS VM address -----------------------------------------------"
ip netns exec "$NS" ip -br addr show "$VF0"

echo ""
echo "-- TC filters on $VF0_REP ingress (TX path, expect in_hw) ----------------"
tc filter show dev "$VF0_REP" ingress

echo ""
echo "-- TC filters on $VXLAN_TUN0 ingress (RX path, expect in_hw) -------------"
tc filter show dev "$VXLAN_TUN0" ingress

###############################################################################
# USAGE GUIDE
###############################################################################
cat <<'USAGE'

+--------------------------------------------------------------------------+
|  Setup complete (no VLAN tagging -- baseline offload validation)          |
+--------------------------------------------------------------------------+
|                                                                           |
|  1. UNDERLAY CONNECTIVITY                                                 |
|     ping -c2 -I 10.0.0.1 10.0.0.2    # direct PF0 underlay, no IPsec   |
|     ping -c2 -I 10.2.0.1 10.2.0.2    # PF0 IPsec tunnel (transport)    |
|     ping -c2 -I 10.3.0.1 10.3.0.2    # PF1 IPsec tunnel (transport)    |
|                                                                           |
|  2. OVERLAY TEST                                                          |
|     Server 2: ip netns exec ns0 iperf3 -s                                |
|     Server 1: ip netns exec ns0 iperf3 --bidi -P 8 -c 192.168.90.3      |
|     Target: 50+ Gbps with full hardware offload                          |
|                                                                           |
|  3. VERIFY FULL BIDIRECTIONAL HARDWARE OFFLOAD                            |
|     ip xfrm state           # all 4 SAs: 'offload packet'               |
|     ip -s xfrm state        # byte/packet counters increment             |
|     ethtool -S enp3s0f0np0 | grep -iE 'ipsec|esp'   # PF0 HW counters  |
|     ethtool -S enp3s0f1np1 | grep -iE 'ipsec|esp'   # PF1 HW counters  |
|     grep -v ' 0$' /proc/net/xfrm_stat   # near 0 = offloaded            |
|     tc filter show dev enp3s0f0r0 ingress   # TX: expect in_hw          |
|     tc filter show dev vxlan_tun0 ingress   # RX: expect in_hw          |
|                                                                           |
|  4. TRANSPARENCY TEST                                                     |
|     tc qdisc del dev enp3s0f0r0 clsact                                   |
|     ip netns exec ns0 iperf3 --bidi -P 8 -c 192.168.90.3                |
|     # should still work via bridge; lower bandwidth expected             |
|     sudo ./test_stack.sh <1|2>   # restore                               |
|                                                                           |
+--------------------------------------------------------------------------+
|  TROUBLESHOOTING                                                          |
|                                                                           |
|  Any 'WARN' lines during setup contain the actual driver error.           |
|  Errors are not suppressed -- each warn shows what the driver rejected.  |
|                                                                           |
|  xfrm tunnel pings fail, no tcpdump traffic on PF:                       |
|    ip route get TUN_REMOTE from TUN_LOCAL  -- confirm src=TUN_LOCAL     |
|    ip xfrm monitor  -- watch for acquire events during ping              |
|    ip -s xfrm state  -- check packet counters increment                  |
|    sysctl net.ipv4.conf.tun0.disable_xfrm  -- must be 0                 |
|                                                                           |
|  'offload packet' missing, SA shows 'offload crypto':                    |
|    DMFS may not have been set before switchdev (Step 2 sequence).        |
|    Re-run the full script.                                               |
|                                                                           |
|  Overlay ping works but < 10 Gbps:                                       |
|    Check 'ip xfrm state' for 'offload packet' on all 4 SAs.             |
|    Check 'tc filter show' for 'hw' flag on prio 30.                     |
|    Both must be active simultaneously for full offload throughput.       |
|                                                                           |
|  NEXT STEP: VLAN-tagged underlay                                          |
|    Once 50+ Gbps is confirmed, the next iteration adds TC vlan push/pop  |
|    rules on PF egress/ingress to restore multiple underlay support       |
|    without using VLAN subifs as the SA offload device.                   |
+--------------------------------------------------------------------------+
USAGE
