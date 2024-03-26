# == Class: nomad_cni::ingress::keepalived
#
#
# === Parameters
#
# [*ingress_inventory*]
#   Array of Hashes containing hosts and ips
#
# [*ingress_vip*]
#   Hash of proxy vip
#
# [*interface*]
#   interface to bind to
#
class nomad_cni::ingress::keepalived (
  Array[Hash] $ingress_inventory,
  Array $ingress_vip,
  String $interface,
) {
  assert_private()

  $this_host = $facts['networking']['hostname']

  # pass is truncated to 8 chars from Keepalived
  $auth_pass = seeded_rand_string(8, "${module_name}${facts['agent_specified_environment']}")

  # we remove IPv6 to get IPv4 only and vice versa
  $ipv4_only_vip = $ingress_vip.filter |$item| { $item !~ Stdlib::IP::Address::V6::CIDR }
  $ipv6_only_vip = $ingress_vip.filter |$item| { $item !~ Stdlib::IP::Address::V4::CIDR }

  if size($ipv4_only_vip) ==  0 {
    fail('You cannot use IPv6 twice for the VIP address array')
  } elsif size($ipv4_only_vip) == 2 {
    fail('You cannot use IPv4 twice for the VIP address array')
  }

  if empty($ipv6_only_vip) {
    $virtual_ipaddress_excluded = []
  } else {
    $virtual_ipaddress_excluded = $ipv6_only_vip.map |$item| { "${item} preferred_lft 0" }
  }

  # we sort the hostnames, and if the current hostname is the first one, we are the master
  $ingress_names = sort($ingress_inventory.map |$item| { $item['name'] })
  if $this_host == $ingress_names[0] { $is_master = true } else { $is_master = false }

  # peer_ip is the ip of the other ingress node
  if $this_host == $ingress_inventory[0]['name'] {
    $peer_ip = $ingress_inventory[0]['ip']
  } else {
    $peer_ip = $ingress_inventory[0]['ip']
  }

  if ($is_master) {
    $state = 'MASTER'
    $priority = 100
  } else {
    $state = 'BACKUP'
    $priority = 99
  }

  class { 'keepalived':
    pkg_ensure      => 'latest',
    sysconf_options => '-D --snmp',
  }

  keepalived::vrrp::instance { 'Nomad_Ingress':
    interface                  => $interface,
    state                      => $state,
    virtual_router_id          => seeded_rand(255, "${module_name}${facts['agent_specified_environment']}") + 0,
    unicast_source_ip          => $facts['networking']['ip'],
    unicast_peers              => [$peer_ip],
    priority                   => $priority + 0,
    auth_type                  => 'PASS',
    auth_pass                  => $auth_pass,
    virtual_ipaddress          => $ipv4_only_vip,
    virtual_ipaddress_excluded => $virtual_ipaddress_excluded,
    track_interface            => [$interface];
  }
}
# vim:ts=2:sw=2
