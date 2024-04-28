# == Class: nomad_cni
#
#
# == Parameters
#
# [*cni_version*] String
# version of CNI to install
#
# [*cni_base_url*] Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl]
# URL to download CNI plugins from
#
# [*keep_vxlan_up_timer_interval*] Integer
# interval in minutes to run systemdd timer job to keep VXLANs up
#
# [*keep_vxlan_up_timer_unit*] Enum['usec', 'msec', 'seconds', 'minutes', 'hours', 'days', 'weeks', 'months', 'years']
# timer unit for the time interval: default minutes
#
# [*manage_firewall_nat*] Boolean
# whether to manage the firewall rules for NAT
#
# [*manage_firewall_vxlan*] Boolean
# whether to manage the firewall rules for the VXLAN
#
# [*interface*] String
# Name of the network Interface to NAT (this is the interface on the host)
#
# [*firewall_provider*] Array[Enum['iptables', 'ip6tables']]
# Iptables providers: ['iptables', 'ip6tables']
#
# [*firewall_rule_order*] Nomad_cni::Digits
# Iptables rule order. It's a string made by digit(s) and it can start with zero(es)
#
# [*cni_cut_off*] Boolean
# Segregate vxlans with iptables
#
# [*vip_address*] Array
#   the IPv4 and or Ipv6 address of the VIP. It can be one of the following:
#   - an array with an IPv4 CIDR and an IPv6 and CIDR
#   - an array with an IPv4 CIDR
#   CIDR means a subnet mask should be provided
#
# [*install_dependencies*] Boolean
#   whether to install the dependencies or not: 'bridge-utils', 'ethtool', 'fping'
#
class nomad_cni (
  Variant[
    Stdlib::IP::Address::V4::CIDR,
    Array[Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR], 2]
  ] $vip_address,
  String $cni_version                                      = '1.4.1',
  Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl] $cni_base_url = 'https://github.com/containernetworking/plugins/releases/download',
  Integer $keep_vxlan_up_timer_interval                    = 1,
  Enum[
    'usec', 'msec', 'seconds', 'minutes', 'hours', 'days', 'weeks', 'months', 'years'
  ] $keep_vxlan_up_timer_unit                              = 'minutes',
  # the parameters below are used to configure the firewall. 
  # You can disregard these settings if you don't want the module to configure the firewall
  # manage_firewall_nat is set to true, so the container can reach the network outside the CNI
  String $interface                                        = 'eth0',
  Boolean $manage_firewall_nat                             = true,
  Boolean $manage_firewall_vxlan                           = false,
  Boolean $cni_cut_off                                     = false,
  Nomad_cni::Digits $firewall_rule_order                   = '050', # string made by digits, which can start with zero(es)
  Array[Enum['iptables', 'ip6tables']] $firewall_provider  = ['iptables'], # ip6tables is NOT supported at the moment
  Boolean $install_dependencies                            = true,
) {
  if $facts['nomad_cni_upgrade'] {
    fail("\nnomad_cni_upgrade fact is set.\nPlease remove all the files under /opt/cni/vxlan/, run puppet and finally REBOOT the server\n")
  }
  if 'ip6tables' in $firewall_provider {
    fail('ip6tables is not supported at the moment')
  }

  class { 'nomad_cni::config':
    cni_version                  => $cni_version,
    cni_base_url                 => $cni_base_url,
    keep_vxlan_up_timer_interval => $keep_vxlan_up_timer_interval,
    keep_vxlan_up_timer_unit     => $keep_vxlan_up_timer_unit,
    ingress_vip                  => $vip_address,
    install_dependencies         => $install_dependencies,
  }

  # == create custom fact directory and avoid conflicts with other modules
  #
  exec { "create custom fact directories from ${module_name}":
    command => 'install -o root -g root -d /etc/facter/facts.d',
    creates => '/etc/facter/facts.d',
    path    => '/bin:/usr/bin',
  }

  # == Firewall setting
  #
  $nr_leading_zeroes = $firewall_rule_order.match(/^0*/)[0].length
  $leading_zeroes = range(1, $nr_leading_zeroes).map |$item| { 0 }.join()

  $_vxlan_rule_order = Integer($firewall_rule_order.regsubst('^0*', '')) + 1
  $vxlan_rule_order = "${leading_zeroes}${_vxlan_rule_order}"

  $_cni_connect_rule_order = Integer($firewall_rule_order.regsubst('^0*', '')) + 1
  $cni_connect_rule_order = "${leading_zeroes}${_cni_connect_rule_order}"

  $_cni_cut_off_rule_order = Integer($firewall_rule_order.regsubst('^0*', '')) + 10
  $cni_cut_off_rule_order = "${leading_zeroes}${_cni_cut_off_rule_order}"

  $nat_rule_order   = $firewall_rule_order

  file { '/etc/facter/facts.d/nomad_cni_firewall_rule_order.yaml':
    require => Exec["create custom fact directories from ${module_name}"],
    content => "---\ncni_connect_rule_order: \"${cni_connect_rule_order}\"\n";
  }

  if ($manage_firewall_nat) or ($manage_firewall_vxlan) or ($cni_cut_off) {
    class { 'nomad_cni::firewall::chain':
      provider   => $firewall_provider,
      rule_order => $firewall_rule_order,
    }
  }

  if ($manage_firewall_nat) {
    class { 'nomad_cni::firewall::nat':
      interface  => $interface,
      rule_order => $nat_rule_order,
      provider   => $firewall_provider,
      require    => Class['nomad_cni::firewall::chain'],
    }
  }

  if ($manage_firewall_vxlan) {
    class { 'nomad_cni::firewall::vxlan':
      interface  => $interface,
      rule_order => $vxlan_rule_order,
      provider   => $firewall_provider,
      require    => Class['nomad_cni::firewall::chain'],
    }
  }

  if ($cni_cut_off) {
    class { 'nomad_cni::firewall::cni_cut_off':
      rule_order => $cni_cut_off_rule_order,
      provider   => $firewall_provider,
      require    => Class['nomad_cni::firewall::chain'],
    }
  }
}
# vim: set ts=2 sw=2 et :
