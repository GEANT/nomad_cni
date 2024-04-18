# == Class: nomad_cni::ingress::keepalived
#
#
# === Parameters
#
# [*ingress_inventory*]
#   Array of Hashes containing hosts and ips
#
# [*ingress_vip*]
#   Array of proxy vip
#
# [*interface*]
#   interface to bind to
#
class nomad_cni::ingress::keepalived (
  Array[Hash] $ingress_inventory,
  Variant[String, Array] $ingress_vip,
  String $interface,
) {
  assert_private()

  # pass is truncated to 8 chars from Keepalived
  $auth_pass = seeded_rand_string(8, "${module_name}${facts['agent_specified_environment']}")

  # we remove IPv6 to get IPv4 only and vice versa
  $ipv4_only_vip_cidr = $ingress_vip ? {
    String => $ingress_vip,
    default => $ingress_vip.filter |$item| { $item !~ Stdlib::IP::Address::V6::CIDR }
  }
  $ipv6_only_vip_cidr = $ingress_vip ? {
    String => [],
    default => $ingress_vip.filter |$item| { $item !~ Stdlib::IP::Address::V4::CIDR }
  }

  if empty($ipv4_only_vip_cidr) {
    fail('You cannot use IPv6 twice for the VIP address array')
  } elsif size($ipv4_only_vip_cidr) == 2 {
    fail('You cannot use IPv4 twice for the VIP address array')
  }

  if empty($ipv6_only_vip_cidr) {
    $virtual_ipaddress_excluded = []
  } else {
    $virtual_ipaddress_excluded = $ipv6_only_vip_cidr.map |$item| { "${item} preferred_lft 0" }
  }

  # we sort the hostnames, and if the current hostname is the first one, we are the master
  # this allows to elect the node with the lowest hostname as the master
  $ingress_names = sort($ingress_inventory.map |$item| { $item['name'] })
  $master = $ingress_inventory.filter |$item| { $item['name'] == $ingress_names[0] }
  $backup = $ingress_inventory.filter |$item| { $item['name'] == $ingress_names[1] }
  if $facts['networking']['hostname'] == $ingress_names[0] {
    $state = 'MASTER'
    $priority = 100
    $peer_ip = $backup[0]['ip']
  } else {
    $state = 'BACKUP'
    $priority = 99
    $peer_ip = $master[0]['ip']
  }

  class { 'nomad_cni::ingress::firewall':
    peer_ip   => $peer_ip,
    interface => $interface,
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
    priority                   => $priority,
    auth_type                  => 'PASS',
    auth_pass                  => $auth_pass,
    virtual_ipaddress          => $ipv4_only_vip_cidr,
    virtual_ipaddress_excluded => $virtual_ipaddress_excluded,
    notify_script_master       => '/usr/local/bin/cni-vxlan-wizard.sh --name all --status up --force',
    notify_script_backup       => '/usr/local/bin/cni-vxlan-wizard.sh --name all --status down --force',
    track_interface            => [$interface];
  }
}
# vim:ts=2:sw=2
