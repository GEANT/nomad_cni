# == Class: nomad_cni::ingress
#
#
# == Parameters
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
# [*agent_regex*] String
#   (requires PuppetDB) a string that match the hostnames of the Nomad agents (use either agent_list or agent_regex)
#
# [*ingress_regex*] String
#   (requires PuppetDB) a string that match the hostnames of the Nomad ingress nodes (use either ingress_list or ingress_regex)
#
# [*agent_list*] Array
#   a list of the Nomad agents (use either agent_list or agent_regex)
#
# [*ingress_list*] Array
#   a list of the Nomad ingress nodes (use either ingress_list or ingress_regex)
#
# [*vip_name*] Optional[Stdlib::Fqdn]
#   the name of the VIP (requires dnsquery module)
#
# [*vip_address*] Optional[Stdlib::IP::Address::V4]
#   ToDo: it can be an array with multiple IPv4 or multiple IPv6 addresses and it won't work
#   the IPv4 and or Ipv6 address of the VIP. It can be one of the following:
#   - undef
#   - an array with an IPv4 address and an IPv6 address
#   - an array with an IPv4 address
#   - an IPv4 address
#
class nomad_cni::ingress (
  Integer $keep_vxlan_up_timer_interval                   = 1,
  Enum[
    'usec', 'msec', 'seconds', 'minutes', 'hours', 'days', 'weeks', 'months', 'years'
  ] $keep_vxlan_up_timer_unit                             = 'minutes',
  # the parameters below are used to configure the firewall.
  # You can disregard these settings if you don't want the module to configure the firewall
  # manage_firewall_nat is set to true, so the container can reach the network outside the CNI
  String $interface                                       = 'eth0',
  Boolean $manage_firewall_nat                            = true,
  Boolean $manage_firewall_vxlan                          = false,
  Boolean $cni_cut_off                                    = false,
  Nomad_cni::Digits $firewall_rule_order                  = '050', # string made by digits, which can start with zero(es)
  Array[Enum['iptables', 'ip6tables']] $firewall_provider = ['iptables'], # ip6tables is NOT supported at the moment
  Optional[String] $agent_regex                           = undef,
  Optional[String] $ingress_regex                         = undef,
  Array $agent_list                                       = [],
  Array $ingress_list                                     = [],
  Optional[Stdlib::Fqdn] $vip_name                        = undef,
  Variant[
    Undef,
    Stdlib::IP::Address::V4,
    Array[Stdlib::IP::Address::V4, 1],
    Array[Variant[Stdlib::IP::Address::V4, Stdlib::IP::Address::V6], 2]
  ] $vip_address = undef,
) {
  if 'ip6tables' in $firewall_provider {
    fail('ip6tables is not supported at the moment')
  }

  # == set the variables
  #
  # extract nomad agent names from the PuppetDB or use the list
  # set number of agents
  # determine CNI ranges
  # create random vxlan ID
  #
  if $agent_list == [] and empty($agent_regex) {
    fail('Either agent_list or agent_regex must be set')
  }
  elsif $agent_list != [] and !empty($agent_regex) {
    fail('Only one of agent_list or agent_regex can be set')
  }
  elsif $agent_list != [] {
    $agent_names = $agent_list
    $agents_inventory = $agent_names.map |$item| {
      $item_inventory = puppetdb_query(
        "inventory[facts.networking.hostname, facts.networking.interfaces.${interface}.ip, facts.networking.interfaces.${interface}.ip6] {
          facts.networking.hostname = '${item}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
        }"
      )
    }
  }
  else {
    $agents_inventory = puppetdb_query(
      "inventory[facts.networking.hostname, facts.networking.interfaces.${interface}.ip, facts.networking.interfaces.${interface}.ip6] {
        facts.networking.hostname ~ '${agent_regex}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
      }"
    )
  }
  $agents_pretty_inventory = $agents_inventory.map |$item| {
    {
      'name' => $item['facts.networking.hostname'],
      'ip' => $item["facts.networking.interfaces.${interface}.ip"],
      'ip6' => $item["facts.networking.interfaces.${interface}.ip6"]
    }
  }

  # extract nomad ingress names from the PuppetDB or use the list
  # set number of ingress nodes
  # determine CNI ranges
  # create random vxlan ID
  #
  if $ingress_list == [] and empty($ingress_regex) {
    fail('Either ingress_list or ingress_regex must be set')
  }
  elsif $ingress_list != [] and !empty($ingress_regex) {
    fail('Only one of ingress_list or ingress_regex can be set')
  }
  elsif $ingress_list != [] {
    $ingress_names = $ingress_list
    $ingress_inventory = $ingress_names.map |$item| {
      $item_inventory = puppetdb_query(
        "inventory[facts.networking.hostname, facts.networking.interfaces.${interface}.ip, facts.networking.interfaces.${interface}.ip6] {
          facts.networking.hostname = '${item}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
        }"
      )
    }
  }
  else {
    $ingress_inventory = puppetdb_query(
      "inventory[facts.networking.hostname, facts.networking.interfaces.${interface}.ip, facts.networking.interfaces.${interface}.ip6] {
        facts.networking.hostname ~ '${ingress_regex}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
      }"
    )
  }
  $ingress_pretty_inventory = $ingress_inventory.map |$item| {
    {
      'name' => $item['facts.networking.hostname'],
      'ip' => $item["facts.networking.interfaces.${interface}.ip"],
      'ip6' => $item["facts.networking.interfaces.${interface}.ip6"]
    }
  }

  $vxlan_dir = '/opt/cni/vxlan'
  $ingress_names = $ingress_pretty_inventory.map |$item| { $item['name'] }
  $ingress_ips = $ingress_pretty_inventory.map |$item| { $item['ip'] }
  $agents_names = $agents_pretty_inventory.map |$item| { $item['name'] }
  $agents_ips = $agents_pretty_inventory.map |$item| { $item['ip'] }
  $inventory = $agents_pretty_inventory + $ingress_pretty_inventory
  $inventory_names = $inventory.map |$item| { $item['name'] }
  $inventory_ips = $inventory.map |$item| { $item['ip'] }

  # determine VIP information
  if empty($vip_address) == [] and empty($vip_address) {
    fail('Either vip_address or vip_address must be set')
  } elsif $vip_name and $vip_address {
    fail('Only one of vip_name or vip_address can be set')
  }

  if ($vip_name) {
    $vip_ipv4 = unique(sort(dnsquery::a($vip_name)))[0]
    $vip_ipv6 = unique(sort(dnsquery::aaaa($vip_name)))
  } else {
    if $vip_address =~ Stdlib::IP::Address::V4 {
      $vip_ipv4 = $vip_address
      $vip_ipv6 = undef
    } elsif $vip_address =~ Array[Variant[Stdlib::IP::Address::V4, Stdlib::IP::Address::V6], 2] {
      $vip_ipv4 = $vip_address[0]
      $vip_ipv6 = $vip_address[1]
    } elsif $vip_address =~ Array[Stdlib::IP::Address::V4, 1] {
      $vip_ipv4 = $vip_address[0]
      $vip_ipv6 = undef
    }
    $vip = undef
  }

  class { 'nomad_cni::ingress::config':
    keep_vxlan_up_timer_interval => $keep_vxlan_up_timer_interval,
    keep_vxlan_up_timer_unit     => $keep_vxlan_up_timer_unit,
  }
  class { 'nomad_cni::ingress::keepalived':
    ingress_inventory => $ingress_pretty_inventory,
    ingress_vip       => [$vip_ipv4, $vip_ipv6],
    interface         => $interface,
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

  $_vxlan_rule_order = $firewall_rule_order.regsubst('^0*', '') + 1
  $vxlan_rule_order = "${leading_zeroes}${_vxlan_rule_order}"

  $_cni_connect_rule_order = $firewall_rule_order.regsubst('^0*', '') + 1
  $cni_connect_rule_order = "${leading_zeroes}${_cni_connect_rule_order}"

  $_cni_cut_off_rule_order = $firewall_rule_order.regsubst('^0*', '') + 10
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
