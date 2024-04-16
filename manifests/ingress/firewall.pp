# == Class: nomad_cni::ingress::firewall
#
#
# === Parameters
#
# [*peer_ip*]
#   the IP addresses of the other node in the cluster.
#
class nomad_cni::ingress::firewall (Stdlib::Ip::Address::Nosubnet $peer_ip) {
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
}
# vim:ts=2:sw=2
