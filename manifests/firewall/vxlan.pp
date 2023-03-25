# Class: nomad_cni::firewall::vxlan
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
class nomad_cni::firewall::vxlan (
  Integer $rule_order,
  Enum['iptables', 'ip6tables'] $provider,
  String $interface,
) {
  # == this is a private class
  #
  assert_private()

  $ip_version = $provider ? {
    'iptables'  => 'ipv4',
    'ip6tables' => 'ipv6',
  }

  @@firewall { "${rule_order} allow UDP traffic on UDP port 4789 through ${interface} for ${provider}":
    tag      => "${module_name}_fw_$${facts['agent_specified_environment']}",
    action   => accept,
    dport    => 4789,
    proto    => udp,
    chain    => 'INPUT',
    provider => iptables,
    source   => $facts['networking'][$interface][$ip_version];
  }

  Firewall <<| tag == "${module_name}_fw_$${facts['agent_specified_environment']}" |>>
}
