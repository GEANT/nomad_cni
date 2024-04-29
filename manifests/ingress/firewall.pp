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
# [*agent_ips*]
#   the IP addresses of the Nomad agents.
#
class nomad_cni::ingress::firewall (
  Stdlib::Ip::Address::Nosubnet $peer_ip,
  String $interface,
  Array[Stdlib::Ip::Address::Nosubnet] $agent_ips,
) {
  $agent_ips.each |$agent_ip| {
    if $agent_ip =~ Stdlib::IP::Address::V6 { $provider = 'ip6tables' } else { $provider = 'iptables' }
    firewall { "200 allow forward through host network ${interface} from Nomad agent ${agent_ip}":
      proto    => 'all',
      chain    => 'FORWARD',
      action   => 'accept',
      provider => $provider,
      outiface => 'br+',
      source   => $agent_ip;
    }
  }
  firewall {
    default:
      proto  => 'all',
      chain  => 'FORWARD',
      action => 'accept';
    "200 allow forward from Bridge to host network ${interface}":
      iniface  => 'br+',
      outiface => $interface;
    '200 allow forward on Bridge':
      iniface  => 'br+',
      outiface => 'br+';
    "200 Allow VRRP inbound from ${peer_ip}":
      proto  => ['vrrp', 'igmp'],
      chain  => 'INPUT',
      source => $peer_ip;
  }
}
# vim:ts=2:sw=2
