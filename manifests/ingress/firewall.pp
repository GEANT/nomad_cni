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
  String $interface,
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
  firewall {
    default:
      proto  => 'all',
      chain  => 'INPUT',
      action => 'accept';
    '200 allow inbound forward':
      iniface  => $interface;
    '200 allow outbound forward':
      outiface  => $interface;
  }
}
# vim:ts=2:sw=2
