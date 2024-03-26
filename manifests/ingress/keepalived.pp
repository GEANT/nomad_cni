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

  # we remove undef values from the vip array
  $def_only_vip = $ingress_vip.filter |$item| { $item !~ Undef }

  # we sort the hostnames, and if the current hostname is the first one, we are the master
  $ingress_names = sort($ingress_inventory.map |$item| { $item['name'] })
  if $this_host == $ingress_names[0] { $is_master = true } else { $is_master = false }

  # peer_ip is the ip of the other ingress node
  if $this_host == $ingress_inventory[0]['name'] {
    $peer_ip = $ingress_inventory[$ingress_inventory[1]]['ip']
  } else {
    $peer_ip = $ingress_inventory[$ingress_names[0]]['ip']
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

  class { 'keepalived::global_defs':
    script_user            => 'root',
    enable_script_security => true;
  }

  keepalived::vrrp::instance { 'Nomad_Ingress':
    interface         => $interface,
    state             => $state,
    virtual_router_id => seeded_rand(255, "${module_name}${facts['agent_specified_environment']}") + 0,
    unicast_source_ip => $facts['networking']['ip'],
    unicast_peers     => [$peer_ip],
    priority          => $priority + 0,
    auth_type         => 'PASS',
    auth_pass         => seeded_rand_string(8, "${module_name}${facts['agent_specified_environment']}"),  # pass is truncated to 8 chars
    virtual_ipaddress => $def_only_vip,
    track_interface   => [$interface];
  }
}
# vim:ts=2:sw=2
