# Class: nomad_cni::firewall::nat
#
#
# == Paramters:
#
# [*interface*] String
# Name of the network Interface to NAT
#
# [*provider*] Enum['iptables', 'ip6tables']
# Iptables provider: iptables or ip6tables
#
# [*rule_order*] Integer
# Iptables rule order
#
class nomad_cni::firewall::nat (
  Integer $rule_order,
  Enum['iptables', 'ip6tables'] $provider,
  String $interface,
) {
  # == this is a private class
  #
  assert_private()

  firewall { "${rule_order} NAT CNI through ${interface} for ${provider}":
    chain    => 'POSTROUTING',
    jump     => 'MASQUERADE',
    proto    => 'all',
    outiface => 'eth0',
    table    => 'nat',
    provider => $provider,
  }
}
