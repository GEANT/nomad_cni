# Class: nomad_cni::firewall::chain
#
#
# == Paramters:
#
# [*provider*] Array[Enum['iptables', 'ip6tables']]
# Iptables providers: ['iptables', 'ip6tables']
#
class nomad_cni::firewall::chain (
  Array[Enum['iptables', 'ip6tables']] $provider,
) {
  if 'iptables' in $provider {
    firewallchain { ['CNI-ISOLATION-INPUT:filter:IPv4', 'CNI-ISOLATION-POSTROUTING:nat:IPv4']:
      ensure  => present,
    }
  }
  if 'ip6tables' in $provider {
    firewallchain { ['CNI-ISOLATION-INPUT:filter:IPv6', 'CNI-ISOLATION-POSTROUTING:nat:IPv6']:
      ensure  => present,
    }
  }
}
