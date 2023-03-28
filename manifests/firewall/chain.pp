# Class: nomad_cni::firewall::chain
#
#
# == Paramters:
#
# [*provider*] Array[Enum['iptables', 'ip6tables']]
# Iptables providers: ['iptables', 'ip6tables']
#
# [*rule_order*] Nomad_cni::Digits
# Iptables rule order
#
class nomad_cni::firewall::chain (
  Array[Enum['iptables', 'ip6tables']] $provider,
  Nomad_cni::Digits $rule_order,
) {
  $provider.each |$iptables_provider| {
    $chain_proto = $iptables_provider ? {
      'iptables'  => 'IPv4',
      'ip6tables' => 'IPv6',
    }
    firewallchain { ["CNI-ISOLATION-INPUT:filter:${chain_proto}", "CNI-ISOLATION-POSTROUTING:nat:${chain_proto}"]:
      ensure => present,
      purge  => true,
    }
    firewall {
      default:
        proto    => all,
        state    => ['NEW'],
        provider => $iptables_provider;
      "${rule_order} jump to CNI-ISOLATION-INPUT chain for ${iptables_provider}":
        chain => 'INPUT',
        jump  => 'CNI-ISOLATION-INPUT';
      "${rule_order} jump to CNI-ISOLATION-POSTROUTING chain for ${iptables_provider}":
        chain => 'POSTROUTING',
        table => 'nat',
        jump  => 'CNI-ISOLATION-POSTROUTING';
    }
  }
}
