# Class: nomad_cni::firewall::vxlan
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
class nomad_cni::firewall::vxlan (
  Nomad_cni::Digits $rule_order,
  Array[Enum['iptables', 'ip6tables']] $provider,
  String $interface,
) {
  assert_private()

  $provider.each |$iptables_provider| {
    $ip_address = $iptables_provider ? {
      'iptables'  => $facts['networking']['interfaces'][$interface]['ip'],
      'ip6tables' => $facts['networking']['interfaces'][$interface]['ip6'],
    }
    @@firewall { "${rule_order} allow traffic on UDP port 4789 through ${interface} from ${ip_address} using provider ${iptables_provider}":
      tag      => "${module_name}_fw_${facts['agent_specified_environment']}",
      action   => accept,
      chain    => 'CNI-ISOLATION-INPUT',
      dport    => 4789,
      proto    => udp,
      provider => $iptables_provider,
      source   => $ip_address;
    }
  }

  Firewall <<| tag == "${module_name}_fw_${facts['agent_specified_environment']}" |>>
}
# vim: set ts=2 sw=2 et :
