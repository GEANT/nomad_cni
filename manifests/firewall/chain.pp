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
  if 'iptables' in $provider {
    firewallchain { ['CNI-ISOLATION-INPUT:filter:IPv4', 'CNI-ISOLATION-POSTROUTING:nat:IPv4']:
      ensure => present,
      purge  => true,
    }
    firewall { "${rule_order} jump to CNI-ISOLATION-INPUT chain for ${provider}":
      chain    => 'INPUT',
      proto    => all,
      state    => ['NEW'],
      jump     => 'CNI-ISOLATION-INPUT',
      provider => 'iptables';
    }
  }

  if 'ip6tables' in $provider {
    firewallchain { ['CNI-ISOLATION-INPUT:filter:IPv6', 'CNI-ISOLATION-POSTROUTING:nat:IPv6']:
      ensure => present,
      purge  => true,
    }
    firewall { "${rule_order} jump to CNI-ISOLATION-INPUT chain for ${provider}":
      chain    => 'INPUT',
      proto    => all,
      state    => ['NEW'],
      jump     => 'CNI-ISOLATION-INPUT',
      provider => 'ip6tables';
    }
  }
}
