# Class: nomad_cni::firewall::cni_cutoff
#
#
# == Paramters:
#
# [*provider*] Enum['iptables', 'ip6tables']
# Iptables provider: iptables or ip6tables
#
# [*rule_order*] Integer
# Iptables rule order
#
class nomad_cni::firewall::cni_cut_off (
  Integer $rule_order,
  Enum['iptables', 'ip6tables'] $provider,
) {
  # == this is a private class
  #
  assert_private()

  $cni_names = $facts['nomad_cni_hash'].keys()
  $networks = $cni_names.map |$item| { $cni_names[$item]['network'] }
  $drop_rule_order = $rule_order + 100

  $cni_names.each |$cni| {
    $my_network = $cni_names[$cni]['network']
    $other_networks = $networks - $my_network

    firewall_multi { "${drop_rule_order} drop traffic from other CNIs to ${cni}":
      action      => 'DROP',
      chain       => 'INPUT',
      source      => $other_networks,
      destination => $my_network,
      proto       => 'all',
      provider    => $provider,
    }
  }
}
# vim: set ts=2 sw=2 et :
