# Class: nomad_cni::firewall::isolate
#
#
class nomad_cni::firewall::isolate (
  $provider = 'iptables',
) {

  $cni_names = $facts['nomad_cni_hash'].keys()
  $network_addresses = $cni_names.map |$key, $value| { $value }

  $test = {
    'cni1' => {
      'id' => '1233456789',
      'network' => '192.168.1.0/24',
    },
  }

  $cni_names.each |$cni_name| {
    $my_network_address = $cni_names[$cni_name]
    $other_cni_names = $cni_names - [$cni_name]
    $other_network_addresses = $network_addresses - $cni_names[$cni_name]
    #$cni_hash = $facts['nomad_cni_hash'][$cni_name]
    firewall_multi { "100 drop traffic to ${cni_name} on ${interface}":
      action   => 'DROP',
      chain    => 'INPUT',
      iniface  => $bridge_name,
      outiface => $other_bridge_names,
      proto    => 'all',
      provider => $provider
    }
    #$cni_hash['interfaces'].each |$interface| {
    #  firewall { "100 allow traffic to ${cni_name} on ${interface}":
    #    action   => 'accept',
    #    chain    => 'INPUT',
    #    iniface  => $interface,
    #    proto    => 'all',
    #    provider => $provider,
    #    require  => Firewall['100 allow all traffic on loopback'],
    #  }
    #}
  }
}
# vim: set ts=2 sw=2 et :
