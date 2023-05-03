# == Define: nomad_cni::macvlan::unicast::firewall
#
# allow traffic from the VXLAN interface to the host
#
# == Parameters
#
# [*vxlan_interface*] String
#   the name of the VXLAN interface
#
#
define nomad_cni::macvlan::unicast::firewall (String $vxlan_interface=$title) {
  if $facts['nomad_cni_rule_order'] {
    $nr_leading_zeroes = $facts['nomad_cni_rule_order'].match(/^0*/)[0].length
    $leading_zeroes = range(1, $nr_leading_zeroes).map |$item| { 0 }.join()
    $_cni_unicast_rule_order = $facts['nomad_cni_rule_order'].regsubst('^0*', '') + 5
    $cni_unicast_rule_order = "${leading_zeroes}${_cni_unicast_rule_order}"

    firewall { "${cni_unicast_rule_order} allow traffic from ${vxlan_interface}":
      action => accept,
      proto  => ['tcp', 'udp'],
      dport  => '1-65535',
    }
  }
}
# vim: set ts=2 sw=2 et :
