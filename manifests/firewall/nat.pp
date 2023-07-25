# Class: nomad_cni::firewall::nat
#
#
# == Parameters
#
# [*interface*] String
# Name of the network Interface to NAT
#
# [*provider*] Enum['iptables', 'ip6tables']
# Iptables provider: iptables or ip6tables
#
# [*rule_order*] Nomad_cni::Digits
# Iptables rule order
#
class nomad_cni::firewall::nat (
  Nomad_cni::Digits $rule_order,
  Array[Enum['iptables', 'ip6tables']] $provider,
  String $interface,
) {
  # == this is a private class
  #
  assert_private()

  # NAT will work on IPv6, but we need to investigate the implications of doing so
  $provider.each |$iptables_provider| {
    firewall { "003 accept forward related established rules for ${iptables_provider} module ${module_name}":
      chain    => 'FORWARD',
      action   => accept,
      provider => $iptables_provider,
      proto    => all,
      state    => ['RELATED', 'ESTABLISHED'];
    }

    firewall { "${rule_order} NAT CNI through ${interface} using provider ${iptables_provider}":
      chain    => 'CNI-ISOLATION-POSTROUTING',
      jump     => 'MASQUERADE',
      proto    => 'all',
      outiface => $interface,
      table    => 'nat',
      provider => $iptables_provider,
    }
  }
}
# vim: set ts=2 sw=2 et :
