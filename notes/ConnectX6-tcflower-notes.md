Example of tc flower vxlan rules configured by OVS:
```
kms15@aratinga:~$ sudo ip -d link show dev vxlan_sys_4789
30: vxlan_sys_4789: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 65000 qdisc noqueue master ovs-system state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether d2:02:df:48:57:e0 brd ff:ff:ff:ff:ff:ff promiscuity 1 allmulti 0 minmtu 68 maxmtu 65535 
    vxlan id 0 srcport 0 0 dstport 4789 ttl auto ageing 300 external nolearning udp_zero_csum6_rx 
    openvswitch_slave addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 tso_max_size 65536 tso_max_segs 65535 gro_max_size 65536 gso_ipv4_max_size 65536 gro_ipv4_max_size 65536

kms15@aratinga:~$ sudo tc filter show dev enp3s0f0r0 ingress
filter protocol ip pref 2 flower chain 0 
filter protocol ip pref 2 flower chain 0 handle 0x1 
  dst_mac 02:00:00:00:00:03
  src_mac 02:00:00:00:00:02
  eth_type ipv4
  ip_tos 0/0x3
  ip_flags nofrag
  in_hw in_hw_count 1
        action order 1: tunnel_key  set
        src_ip 192.168.80.2
        dst_ip 192.168.80.3
        key_id 1024
        dst_port 4789
        nocsum  nofrag
        ttl 64 pipe
         index 1 ref 1 bind 1
        no_percpu
        used_hw_stats delayed

        action order 2: mirred (Egress Redirect to device vxlan_sys_4789) stolen
        index 1 ref 1 bind 1
        cookie 6fad19ef604e9195e776019a21754ba0
        no_percpu
        used_hw_stats delayed

kms15@aratinga:~$ sudo tc filter show dev vxlan_sys_4789 ingress
filter protocol ip pref 2 flower chain 0 
filter protocol ip pref 2 flower chain 0 handle 0x1 
  dst_mac 02:00:00:00:00:02
  src_mac 02:00:00:00:00:03
  eth_type ipv4
  enc_dst_ip 192.168.80.2
  enc_src_ip 192.168.80.3
  enc_key_id 1024
  enc_dst_port 4789
  enc_tos 0
  ip_flags nofrag
  enc_flags notuncsum/notundf
  in_hw in_hw_count 2
        action order 1: tunnel_key  unset pipe
         index 2 ref 1 bind 1
        no_percpu
        used_hw_stats delayed

        action order 2: mirred (Egress Redirect to device enp3s0f0r0) stolen
        index 2 ref 1 bind 1
        cookie 51e80574e64895bc43843f88d7ee219e
        no_percpu
        used_hw_stats delayed
```

