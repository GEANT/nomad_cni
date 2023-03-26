# Class: nomad_cni::firewall::chain
#
#
# == Paramters:
#
# [*provider*] Array[Enum['iptables', 'ip6tables']]
# Iptables providers: ['iptables', 'ip6tables']
#
# [*rule_order*] Integer
# Iptables rule order
#
class nomad_cni::firewall::chain (
  Array[Enum['iptables', 'ip6tables']] $provider,
  Integer $rule_order,
) {
  $drop_rule_order = $rule_order + 20

  if 'iptables' in $provider {
    firewallchain { ['CNI-ISOLATION-INPUT:filter:IPv4', 'CNI-ISOLATION-POSTROUTING:nat:IPv4']:
      ensure => present,
      purge  => true,
    }
    firewall { "${drop_rule_order} deny all other inbound requests on chain CNI-ISOLATION-INPUT for provider iptables":
      action   => drop,
      chain    => 'CNI-ISOLATION-INPUT',
      provider => 'iptables';
    }
  }

  if 'ip6tables' in $provider {
    firewallchain { ['CNI-ISOLATION-INPUT:filter:IPv6', 'CNI-ISOLATION-POSTROUTING:nat:IPv6']:
      ensure => present,
      purge  => true,
    }
    firewall { "${drop_rule_order} deny all other inbound requests on chain CNI-ISOLATION-INPUT for provider ip6tables":
      action   => drop,
      chain    => 'CNI-ISOLATION-INPUT',
      provider => 'ip6tables';
    }
  }
}
