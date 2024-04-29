# Class: nomad_cni::firewall::cni_cutoff
#
#
# == Parameters
#
# [*provider*] Enum['iptables', 'ip6tables']
# Iptables provider: iptables or ip6tables
#
# [*rule_order*] Nomad_cni::Digits
# Iptables rule order
#
class nomad_cni::firewall::cni_cut_off (
  Nomad_cni::Digits $rule_order,
  Array[Enum['iptables', 'ip6tables']] $provider,
) {
  assert_private()

  $cni_names = $facts['nomad_cni_hash'].keys()
  $networks = $cni_names.map |$item| { $facts['nomad_cni_hash'][$item]['network'] }

  if 'iptables' in $provider {
    $cni_names.each |$cni| {
      $my_network = $facts['nomad_cni_hash'][$cni]['network']
      $networks.each |$network| {
        firewall { "${rule_order} drop traffic from ${cni} ${my_network} to CNI ${network} using provider iptables":
          action      => drop,
          chain       => 'CNI-ISOLATION-INPUT',
          source      => $my_network,
          destination => $network,
          proto       => 'all',
          provider    => 'iptables',
        }
      }
    }
  }

  if 'ip6tables' in $provider {
    $cni_names.each |$cni| {
      $my_network = $facts['nomad_cni_hash'][$cni]['network6']  # TODO: ipv6 (the custom fact is not yet ready)

      $networks.each |$network| {
        firewall { "${rule_order} drop traffic from ${cni} ${my_network} to CNI ${network} using provider ip6tables":
          action      => drop,
          chain       => 'CNI-ISOLATION-INPUT',
          source      => $my_network,
          destination => $network,
          proto       => 'all',
          provider    => 'ip6tables',
        }
      }
    }
  }
}
# vim: set ts=2 sw=2 et :
