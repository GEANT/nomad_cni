# == Class: nomad_cni::ingress::firewall
#
#
# === Parameters
#
# [*peer_ip*]
#   the IP addresses of the other node in the cluster.
#
# [*interface*]
#   the network interface to apply the firewall rules to.
#
class nomad_cni::ingress::firewall (
  Stdlib::Ip::Address::Nosubnet $peer_ip,
  String $interface = 'eth0',
) {
  firewall { "200 Allow VRRP inbound from ${peer_ip}":
    action => accept,
    proto  => ['vrrp', 'igmp'],
    chain  => 'INPUT',
    source => $peer_ip;
  }
  firewall { '200 Allow VRRP inbound to multicast':
    proto       => ['vrrp', 'igmp'],
    chain       => 'INPUT',
    destination => '224.0.0.0/8';
  }
  firewall { '200 allow forward':
    proto    => 'all',
    chain    => 'FORWARD',
    iniface  => $interface,
    outiface => $interface,
    action   => 'accept';
  }
}
# vim:ts=2:sw=2
