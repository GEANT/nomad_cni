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

  $cni_names = $facts['nomad_cni_hash'].keys()
  $networks = $cni_names.map |$item| { $cni_names[$item]['network'] }
  $drop_rule_order = $rule_order + 30

  if $provider.size == 1 {
    $cni_names.each |$cni| {
      $my_network = $cni_names[$cni]['network']

      firewall_multi { "${drop_rule_order} drop traffic from ${cni} to other CNIs":
        action      => drop,
        chain       => 'CNI-ISOLATION-INPUT',
        source      => $my_network,
        destination => $networks,
        proto       => 'all',
        provider    => $provider[0],
      }
    }
  } else {
    # place-holder for future implementation
    fail('IPv6 provider not yet implemented')
  }
}
# vim: set ts=2 sw=2 et :
