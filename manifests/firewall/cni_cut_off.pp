# Class: nomad_cni::firewall::cni_cutoff
#
#
# == Paramters:
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
  # == this is a private class
  #
  assert_private()

  $test_hash = {
    'test_cni_1' => {
      'id' => '11882895',
      'network' => '192.168.2.1/24'
    },
    'test_cni_2' => {
      'id' => '5199537',
      'network' => '192.168.3.1/24'
    },
    'test_cni_3' => {
      'id' => '15782095',
      'network' => '192.168.4.1/24'
    }
  }

  $cni_names = $facts['nomad_cni_hash'].keys()
  $networks = $cni_names.map |$item| { $facts['nomad_cni_hash'][$item]['network'] }
  $drop_rule_order = $rule_order + 30

  if 'iptables' in $provider {
    $cni_names.each |$cni| {
      $my_network = $cni_names[$cni]['network']
      $networks.each |$network| {
        firewall { "${drop_rule_order} drop traffic from ${cni} ${my_network} to CNI ${network} using provider iptables":
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
      $my_network = $cni_names[$cni]['network']  # TODO: ipv6 (the custom fact is not yet ready)

      $networks.each |$network| {
        firewall { "${drop_rule_order} drop traffic from ${cni} ${my_network} to CNI ${network} using provider ip6tables":
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
