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
# [*manage_fw_nat*] Boolean
# whether to manage the firewall rules for NAT
#
# [*manage_fw_vxlan*] Boolean
# whether to manage the firewall rules for the VXLAN
#
# [*interface*] String
# Name of the network Interface to NAT
#
# [*fw_provider*] Enum['iptables', 'ip6tables']
# Iptables provider: iptables or ip6tables
#
# [*fw_rule_order*] Integer
# Iptables rule order
#
class nomad_cni (
  String $cni_version = '1.2.0',
  Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl] $cni_base_url = 'https://github.com/containernetworking/plugins/releases/download',
  Boolean $keep_vxlan_up_cron_ensure          = true,
  Integer[1, 59] $keep_vxlan_up_cron_interval = 10,
  # the parameters below are used to configure the firewall (ignore them if you don't want this module to configure the firewall)
  String $interface                           = 'eth0',
  Boolean $manage_fw_nat                      = false,
  Boolean $manage_fw_vxlan                    = false,
  Integer $fw_rule_order                      = 150,
  Enum['iptables', 'ip6tables'] $fw_provider  = 'iptables',
) {
  class { 'nomad_cni::config':
    cni_version                 => $cni_version,
    cni_base_url                => $cni_base_url,
    keep_vxlan_up_cron_ensure   => $keep_vxlan_up_cron_ensure,
    keep_vxlan_up_cron_interval => $keep_vxlan_up_cron_interval,
  }

  if ($manage_fw_nat) {
    class { 'nomad_cni::firewall::nat':
      interface  => $interface,
      rule_order => $fw_rule_order,
      provider   => $fw_provider,
    }
  }

  if ($manage_fw_vxlan) {
    class { 'nomad_cni::firewall::vxlan':
      interface  => $interface,
      rule_order => $fw_rule_order,
      provider   => $fw_provider,
    }
  }
}
