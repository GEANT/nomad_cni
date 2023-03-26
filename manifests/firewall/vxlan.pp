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
  Array[Enum['iptables', 'ip6tables']] $provider,
  String $interface,
) {
  # == this is a private class
  #
  assert_private()

  ['iptables', 'ip6tables'].each |$iptables_provider| {
    $ip_address = $iptables_provider ? {
      'iptables'  => $facts['networking'][$interface]['ip'],
      'ip6tables' => $facts['networking'][$interface]['ip6'],
    }
    if $iptables_provider in $provider {
      @@firewall { "100 allow traffic on UDP port 4789 through ${interface} for provider ${iptables_provider}":
        tag      => "${module_name}_fw_$${facts['agent_specified_environment']}",
        action   => accept,
        chain    => 'CNI-ISOLATION-INPUT',
        dport    => 4789,
        proto    => udp,
        provider => $iptables_provider,
        source   => $ip_address;
      }
    }
  }

  Firewall <<| tag == "${module_name}_fw_$${facts['agent_specified_environment']}" |>>
}
