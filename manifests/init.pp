# @summary Class: nomad_cni
#
# @param vip_cidr
#   the IPv4 and or Ipv6 address of the VIP. It can be one of:
#     - String or Array with an IPv4 CIDR
#     - Array with an IPv4 CIDR and an IPv6 CIDR
#   CIDR examples: '192.168.10.15/24' or ['192.168.10.15/24', '2001:db8::1/64']
#   Type: Nomad_cni::Vip::Cidr
#
# @param cni_version
#   version of CNI to install
#   Default: '1.4.0'
#   Type: String
#
# @param cni_base_url
#   URL to download CNI plugins from
#   Default: 'https://github.com/containernetworking/plugins/releases/download'
#   Type: Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl]
#
# @param keep_vxlan_up_timer_interval
#   interval in minutes to run systemd timer job to keep VXLANs up
#   Default: 10
#   Type: Integer
#
# @param keep_vxlan_up_timer_unit
#   timer unit for the time interval: default minutes
#   Default: 'minutes' 
#   Type: Enum['usec', 'msec', 'seconds', 'minutes', 'hours', 'days', 'weeks', 'months', 'years']
#
# @param manage_firewall_nat
#   whether to manage the firewall rules for NAT
#   Default: true
#   Type: Boolean
#
# @param manage_firewall_vxlan
#   whether to manage the firewall rules for the VXLAN
#   Default: false
#   Type: Boolean
#
# @param interface
#   Name of the network Interface to NAT (this is the interface on the host)
#   Default: 'eth0'
#   Type: String
#
# @param firewall_provider
#   Iptables providers: ['iptables', 'ip6tables']
#   Default: ['iptables']
#   Type: Array[Enum['iptables', 'ip6tables']]
#
# @param firewall_rule_order
#   Iptables rule order. It's a string made by digit(s) and it can start with zero(es)
#   Default: '050'
#   Type: Nomad_cni::Digits
#
# @param cni_cut_off
#   Segregate vxlans with iptables
#   Default: false
#   Type: Boolean
#
# @param install_dependencies
#   whether to install the dependencies or not: 'bridge-utils', 'ethtool', 'fping'
#   Default: true
#   Type: Boolean
#
# @param workaround_network_restart
#   if the network is restarted the CNI stops working and the jobs must be redeployed
#   the workaround consists of reloading the CNI services, and then drain and undrain the node
#   Default: false
#   Type: Boolean
#
# @param nomad_token
#   the token used to drain/undrain the node
#   it's mandatory if workaround_network_restart is set to true
#   Default: undef
#   Type: Optional[Sensitive]
#
# @param nomad_proto
#   the protocol to use. It must be http or https
#   Default: http
#   Type: Enum['http', 'https']
#
# @param nomad_port
#   the Nomad port.
#   Default: 4646
#   Type: Stdlib::Port
#
# @param nomad_listen_address
#   the address to which Nomad listens. It must be an IP address without subnet. 
#   Default: 127.0.0.1
#   Type: Stdlib::Ip::Address::Nosubnet
#
# @param nomad_data_dir
#   Nomad data directory.
#   Default: /var/lib/nomad
#   Type: Stdlib::Absolutepath
#
class nomad_cni (
  Nomad_cni::Vip::Cidr $vip_cidr, # see above for the format
  String $cni_version                                      = '1.4.0',
  Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl] $cni_base_url = 'https://github.com/containernetworking/plugins/releases/download',
  Integer $keep_vxlan_up_timer_interval                    = 10,
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
  # apply workaround when systemd-networkd is reloaded
  # it assumes that `nomad` executable is in the PATH
  Boolean $workaround_network_restart                 = false,
  Optional[Sensitive] $nomad_token                    = undef,
  Enum['http', 'https'] $nomad_proto                  = 'http',
  Stdlib::Port $nomad_port                            = 4646,
  Stdlib::Ip::Address::Nosubnet $nomad_listen_address = '127.0.0.1',
  Stdlib::Absolutepath $nomad_data_dir                = '/var/lib/nomad'
) {
  if $facts['nomad_cni_upgrade'] {
    fail("\nnomad_cni_upgrade fact is set.\nPlease remove all the files under /opt/cni/vxlan/, run puppet and finally REBOOT the server\n")
  }
  if 'ip6tables' in $firewall_provider {
    fail('ip6tables is not supported at the moment')
  }
  if $workaround_network_restart {
    unless $nomad_token { fail("\$nomad_token is mandatory when \$workaround_network_restart is set to true") }
  }

  class { 'nomad_cni::config':
    cni_version                  => $cni_version,
    cni_base_url                 => $cni_base_url,
    keep_vxlan_up_timer_interval => $keep_vxlan_up_timer_interval,
    keep_vxlan_up_timer_unit     => $keep_vxlan_up_timer_unit,
    ingress_vip                  => $vip_cidr,
    install_dependencies         => $install_dependencies,
    workaround_network_restart   => $workaround_network_restart,
    nomad_token                  => $nomad_token,
    nomad_proto                  => $nomad_proto,
    nomad_port                   => $nomad_port,
    nomad_data_dir               => $nomad_data_dir,
    nomad_listen_address         => $nomad_listen_address,
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

  file {
    default:
      require => Exec["create custom fact directories from ${module_name}"];
    '/etc/facter/facts.d/nomad_cni_firewall_rule_order.yaml':
      content => "---\ncni_connect_rule_order: \"${cni_connect_rule_order}\"\n";
    '/etc/facter/facts.d/cni_services.rb':
      mode   => '0755',
      source => "puppet:///modules/${module_name}/cni_services.rb";
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
