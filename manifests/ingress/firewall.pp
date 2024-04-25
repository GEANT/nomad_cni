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
    "200 allow forward on Bridge iniface ${interface}":
      iniface  => 'br+',
      outiface => $interface;
    "200 allow forward on Bridge iniface ${interface}":
      outiface => 'br+',
      iniface  => $interface;
      #source   => 'ipset nomade-nodes';
    '200 allow forward on Bridge':
      iniface  => 'br+',
      outiface => 'br+';
    #'200 allow forward from Bridge to VXLAN':
    #  iniface  => 'br+',
    #  outiface => 'vx+';
    #'200 allow forward from VXLAN to Bridge':
    #  iniface  => 'vx+',
    #  outiface => 'br+';
    "200 Allow VRRP inbound from ${peer_ip}":
      proto  => ['vrrp', 'igmp'],
      chain  => 'INPUT',
      source => $peer_ip;
  }
}
# vim:ts=2:sw=2
