# == Class: nomad_cni::ingress::keepalived
#
#
# === Parameters
#
# [*ingress_pretty_inventory*]
#   Array of Hashes containing hosts and ips
#
# [*ingress_vip*]
#   Hash of proxy vip
#
class nomad_cni::ingress::keepalived (
  Array[Hash] $ingress_pretty_inventory,
  Stdlib::IP::Address::V4::Cidr $ingress_vip,
) {
  $ingress_names = sort($ingress_pretty_inventory.map |$item| { $item['name'] })
  $ingress_ips = $ingress_pretty_inventory.map |$item| { $item['ip'] }

  case $facts['networking']['fqdn'] {
    $ingress_names[0]: {
      $state = 'MASTER'
      $priority = 100
      $peer_ip = $ingress_pretty_inventory[$ingress_names[1]]['ip']
    }
    default: {
      $state = 'BACKUP'
      $priority = 99
      $peer_ip = $ingress_pretty_inventory[$ingress_names[0]]['ip']
    }
  }

  class { 'keepalived':
    pkg_ensure                  => 'latest',
    sysconf_options             => '-D --snmp',
    include_external_conf_files => ['/etc/keepalived/keepalived-wp.conf'],
  }

  class { 'keepalived::global_defs':
    script_user            => 'root',
    enable_script_security => true;
  }

  keepalived::vrrp::script { 'check_haproxy':
    script   => '/usr/local/bin/cni-vxlan-wizard.sh --status check --name all',
    weight   => 2,  # integer added/removed to/from priority
    rise     => 1,  # required number of OK
    fall     => 1,  # required number of KO
    interval => 2;
  }

  keepalived::vrrp::instance { 'HAProxy':
    interface         => 'eth0',
    state             => $state,
    virtual_router_id => seeded_rand(255, "${module_name}${facts['agent_specified_environment']}") + 0,
    unicast_source_ip => $facts['networking']['ip'],
    unicast_peers     => [$peer_ip],
    priority          => $priority + 0,
    auth_type         => 'PASS',
    auth_pass         => seeded_rand_string(8, "${module_name}${facts['agent_specified_environment']}"),  # pass is truncated to 8 chars
    virtual_ipaddress => $ingress_vip,
    track_script      => 'check_haproxy',
    track_interface   => ['eth0'];
  }
}
# vim:ts=2:sw=2
