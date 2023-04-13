# == Function: nomad_cni::host_network
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
function nomad_cni::host_network(
  String $iface,
) >> Array[Hash] {
  $fqdn_inventory = puppetdb_query(
    "inventory[facts.networking.interfaces.${iface}.ip, facts.networking.interfaces.${iface}.netmask] {
      facts.networking.fqdn = '${facts['networking']['fqdn']}'
    }"
  )[0]
  $fqdn_ip = $fqdn_inventory["facts.networking.interfaces.${iface}.ip"]
  $fqdn_mask = $fqdn_inventory["facts.networking.interfaces.${iface}.netmask"]
  $fqdn_cidr = inline_template("<%= require 'ipaddr'; IPAddr.new(@fqdn_mask).to_i.to_s(2).count('1') %>")
  $public_network = [
    'public' => {
      'cidr' => "${fqdn_ip}/${fqdn_cidr}",
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
