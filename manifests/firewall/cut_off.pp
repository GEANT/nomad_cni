# Class: nomad_cni::firewall::cut_off
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
class nomad_cni::firewall::cut_off (
  Integer $rule_order,
  Enum['iptables', 'ip6tables'] $provider,
) {
  # == this is a private class
  #
  assert_private()

  $cni_names = $facts['nomad_cni_hash'].keys()
  $networks = $cni_names.map |$item| { $cni_names[$item]['network'] }

  $cni_names.each |$cni_name| {
    $my_network = $cni_names[$cni_name]
    $other_networks = $networks - $my_network

    firewall_multi { "100 drop traffic from other CNIs to ${cni_name}":
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
