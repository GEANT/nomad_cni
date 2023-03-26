# == Class: nomad_cni
#
#
# == Paramters:
#
# [*cni_version*] String
# version of CNI to install
#
# [*cni_base_url*] Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl]
# URL to download CNI plugins from
#
# [*keep_vxlan_up_cron_ensure*] Boolean
# install cron job to keep VXLANs up
#
# [*keep_vxlan_up_cron_interval*] Integer[1, 59]
# interval in minutes to run cron job to keep VXLANs up
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
# [*firewall_rule_order*] Integer
# Iptables rule order
#
# [*cni_cut_off*] Boolean
# Segregate vxlans with iptables
#
class nomad_cni (
  String $cni_version = '1.2.0',
  Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl] $cni_base_url = 'https://github.com/containernetworking/plugins/releases/download',
  Boolean $keep_vxlan_up_cron_ensure                       = true,
  Integer[1, 59] $keep_vxlan_up_cron_interval              = 10,
  # the parameters below are used to configure the firewall (ignore them if you don't want this module to configure the firewall)
  String $interface                                        = 'eth0',
  Boolean $manage_firewall_nat                             = false,
  Boolean $manage_firewall_vxlan                           = false,
  Boolean $cni_cut_off                                     = false,
  Integer $firewall_rule_order                             = 150,
  Array[Enum['iptables', 'ip6tables']] $firewall_provider  = ['iptables'], # be aware that ip6tables is NOT supported at the moment
) {
  if 'ip6tables' in $firewall_provider {
    fail('ip6tables is not supported at the moment')
  }

  class { 'nomad_cni::config':
    cni_version                 => $cni_version,
    cni_base_url                => $cni_base_url,
    keep_vxlan_up_cron_ensure   => $keep_vxlan_up_cron_ensure,
    keep_vxlan_up_cron_interval => $keep_vxlan_up_cron_interval,
  }

  # == Firewall setting
  #
  if ($manage_firewall_nat) or ($manage_firewall_vxlan) or ($cni_cut_off) {
    class { 'nomad_cni::firewall::chain':
      provider => $firewall_provider,
    }
  }

  if ($manage_firewall_nat) {
    class { 'nomad_cni::firewall::nat':
      interface  => $interface,
      rule_order => $firewall_rule_order,
      provider   => $firewall_provider,
      require    => Class['nomad_cni::firewall::chain'],
    }
  }

  if ($manage_firewall_vxlan) {
    class { 'nomad_cni::firewall::vxlan':
      interface  => $interface,
      rule_order => $firewall_rule_order,
      provider   => $firewall_provider,
      require    => Class['nomad_cni::firewall::chain'],
    }
  }

  if ($cni_cut_off) {
    class { 'nomad_cni::firewall::cni_cut_off':
      rule_order => $firewall_rule_order,
      provider   => $firewall_provider,
      require    => Class['nomad_cni::firewall::chain'],
    }
  }
}
