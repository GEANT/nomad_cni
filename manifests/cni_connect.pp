# == Define: nomad_cni::cni_connect
#
#
# == Paramters:
#
# [*cni_array*] Array
# CNIs to interconnect
#
# [*provider*] Enum['iptables', 'ip6tables']
# Iptables provider: iptables or ip6tables
#
# [*firewall_connect_rule_order*] Integer
# Iptables rule order
#
#
# == Example:
#
# nomad_cni::cni_connect {['cni1', 'cni2']: }
#
define nomad_cni::cni_connect (
  Array $cni_array = $name,
  Integer $firewall_connect_rule_order = 5,
  Enum['iptables', 'ip6tables'] $provider = 'iptables',
) {
  unless defined(Class['nomad_cni::firewall::vxlan']) {
    fail('nomad_cni::cni_connect requires nomad_cni::firewall::cni_cut_off to be defined')
  }
  if $cni_array.size < 2 {
    fail('you need to define at least 2 CNIs to connect')
  }

  $cni_names = $facts['nomad_cni_hash'].keys()
  $networks = $cni_names.map |$item| { $facts['nomad_cni_hash'][$item]['network'] }
  $cni_array.each |$cni| {
    if ! defined(Nomad_cni::Macvlan::Unicast::V4[$cni]) and ! defined(Nomad_cni::Macvlan::Multicast::V4[$cni]) {
      fail("CNI ${cni} does not exist")
    }
  }

  $cni_names.each |$cni| {
    $my_network = $facts['nomad_cni_hash'][$cni]['network']
    $other_networks = $networks - $my_network

    $other_networks.each | $other | {
      # it can happen that the fact was not yet uploaded
      if $cni in $cni_names and ($my_network) {
        firewall_multi { "${firewall_connect_rule_order} allow traffic from other CNIs to ${cni}":
          action      => 'ACCEPT',
          chain       => 'CNI-ISOLATION-INPUT',
          source      => $other,
          destination => $my_network,
          proto       => 'all',
          provider    => $provider,
        }
      }
    }
  }
}
