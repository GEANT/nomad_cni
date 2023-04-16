# == Function: nomad_cni::host_network_v4
#
# create host_network (array of hashes) for Nomad agent configuration
#
# parse $facts['nomad_cni_hash'], add public network and return an array of hashes for host_network
#
# === Example
#
#   nomad_cni::host_network('eth0')
#
# === Output example
#
#  [
#    {
#      'public' => {
#        'cidr' => '192.168.1.1/24',
#        'interface' => 'eth0'
#      }
#    }, {
#      'test_cni_1' => {
#        'cidr' => '192.168.2.1/24',
#        'interface' => 'vxbr8365519'
#      }
#    }, {
#      'test_cni_2' => {
#        'cidr' => '192.168.3.1/24',
#        'interface' => 'vxbr5199537'
#      }
#    }
#  ]
#
# === Parameters
#
# [*iface*] String
#   network interface on the Nomad agents
#
function nomad_cni::host_network_v4(
  String $iface,
) >> Variant[Array[0, 0], Array[Hash]] {
  unless $iface in $facts['networking']['interfaces'] {
    fail("Interface ${iface} not found in \$facts['networking']['interfaces']")
  }
  $ip = $facts['networking']['interfaces'][$iface]['ip']
  $mask = $facts['networking']['interfaces'][$iface]['netmask']
  $cidr = inline_template("<%= require 'ipaddr'; IPAddr.new(@mask).to_i.to_s(2).count('1') %>")

  $public_network = [
    'public' => {
      'cidr' => "${ip}/${cidr}",
      'interface' => $iface,
    },
  ]

  if !empty($facts['nomad_cni_hash']) {
    $cni_names = $facts['nomad_cni_hash'].keys
    $cni_host_networks = $cni_names.map |$cni| {
      {
        $cni => {
          'cidr' => $facts['nomad_cni_hash'][$cni]['network'],
          'interface' => "vxbr${facts['nomad_cni_hash'][$cni]['id']}",
        }
      }
    }
  } else {
    $cni_host_networks = []
  }

  concat($public_network, $cni_host_networks)
}
