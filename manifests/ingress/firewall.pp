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
  firewall {
    default:
      proto  => 'all',
      chain  => 'FORWARD',
      action => 'accept';
    "200 allow forward on VXLAN iniface ${interface}":
      iniface  => 'vx+',
      outiface => $interface;
    "200 allow forward on Bridge iniface ${interface}":
      iniface  => 'br+',
      outiface => $interface;
    "200 Allow VRRP inbound from ${peer_ip}":
      proto  => ['vrrp', 'igmp'],
      chain  => 'INPUT',
      source => $peer_ip;
  }
}
# vim:ts=2:sw=2
