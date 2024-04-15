# == Define: nomad_cni::ingress::vxlan::v4
#
# configure CNI and Unicast VXLAN/Bridge for Nomad
#
# == Parameters
#
# [*ingress_vip*]
#   the VIP for the CNI
# [*cni_name*] String
#   the name of the CNI
#
# [*network*] Stdlib::IP::Address::V4::CIDR
#   Network and Mask for the CNI
#
# [*agent_regex*] String
#   (requires PuppetDB) a string that match the hostnames of the Nomad agents (use either agent_list or agent_regex)
#
# [*ingress_regex*] String
#   (requires PuppetDB) a string that match the hostnames of the Nomad ingress nodes (use either agent_list or agent_regex)
#
# [*agent_list*] Array
#   a list of the Nomad agents (use either agent_list or agent_regex)
#
# [*ingress_list*] Array
#   a list of the Nomad ingress nodes (use either agent_list or agent_regex)
#
# [*iface*] String
#   network interface on the Nomad agents
#
# [*nolearning*] Boolean
#   disable learning of MAC addresses on the bridge interface
#   DID NOT WORK AS EXPECTED. It may require testing and maybe an improved configuration
#
# [*min_networks*] Optional[Integer]
#   minimum number of networks to be created. If the number of agents is less than this number, the module will fail
#   check the README file for more details
#
define nomad_cni::ingress::vxlan::v4 (
  Stdlib::IP::Address::V4::CIDR $network,
  Variant[Stdlib::IP::Address::V4::Nosubnet, Stdlib::Fqdn] $ingress_vip,
  Optional[String] $ingress_regex = undef,
  String $cni_name                = $name,
  Optional[String] $agent_regex   = undef,
  Array $agent_list               = [],
  Array $ingress_list             = [],
  String $iface                   = 'eth0',
  Boolean $nolearning             = false,  # please read the docs carefully before enabling this option
  Optional[Integer] $min_networks = undef,
) {
  # == ensure that nomad_cni class was included and that the name is not reserved
  #
  if $cni_name == 'all' {
    fail('the name \'all\' is reserved and it cannot be used as a CNI name')
  }

  # == set the variables
  #
  # extract nomad agent names from the PuppetDB or use the list
  # set number of agents
  # determine CNI ranges
  # create random vxlan ID
  #
  if $agent_list == [] and empty($agent_regex) {
    fail('Either agent_list or agent_regex must be set')
  } elsif $agent_list != [] and !empty($agent_regex) {
    fail('Only one of agent_list or agent_regex can be set')
  } elsif $agent_list != [] {
    $agent_names = $agent_list
    $agents_inventory = $agent_names.map |$item| {
      $item_inventory = puppetdb_query(
        "inventory[facts.networking.hostname, facts.networking.interfaces.${iface}.ip, facts.networking.interfaces.${iface}.mac] {
          facts.networking.hostname = '${item}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
        }"
      )
    }
  }
  else {
    $agents_inventory = puppetdb_query(
      "inventory[facts.networking.hostname, facts.networking.interfaces.${iface}.ip, facts.networking.interfaces.${iface}.mac] {
        facts.networking.hostname ~ '${agent_regex}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
      }"
    )
  }
  $agents_pretty_inventory = $agents_inventory.map |$item| {
    {
      'name' => $item['facts.networking.hostname'],
      'ip' => $item["facts.networking.interfaces.${iface}.ip"],
      'mac' => $item["facts.networking.interfaces.${iface}.mac"]
    }
  }

  # extract nomad ingress names from the PuppetDB or use the list
  # set number of ingress nodes
  # determine CNI ranges
  # create random vxlan ID
  #
  if $ingress_list == [] and empty($ingress_regex) {
    fail('Either ingress_list or ingress_regex must be set')
  } elsif $ingress_list != [] and !empty($ingress_regex) {
    fail('Only one of ingress_list or ingress_regex can be set')
  } elsif $ingress_list != [] {
    $ingress_names = $ingress_list
    $ingress_inventory = $ingress_names.map |$item| {
      $item_inventory = puppetdb_query(
        "inventory[facts.networking.hostname, facts.networking.interfaces.${iface}.ip, facts.networking.interfaces.${iface}.mac] {
          facts.networking.hostname = '${item}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
        }"
      )
    }
  }
  else {
    $ingress_inventory = puppetdb_query(
      "inventory[facts.networking.hostname, facts.networking.interfaces.${iface}.ip, facts.networking.interfaces.${iface}.mac] {
        facts.networking.hostname ~ '${ingress_regex}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
      }"
    )
  }
  $ingress_pretty_inventory = $ingress_inventory.map |$item| {
    {
      'name' => $item['facts.networking.hostname'],
      'ip' => $item["facts.networking.interfaces.${iface}.ip"],
      'mac' => $item["facts.networking.interfaces.${iface}.mac"]
    }
  }

  $vxlan_dir = '/opt/cni/vxlan'
  $ingress_names = $ingress_pretty_inventory.map |$item| { $item['name'] }
  $ingress_ips = $ingress_pretty_inventory.map |$item| { $item['ip'] }
  $agents_names = $agents_pretty_inventory.map |$item| { $item['name'] }
  $agents_ips = $agents_pretty_inventory.map |$item| { $item['ip'] }
  $inventory = $agents_pretty_inventory + $ingress_pretty_inventory
  $inventory_names = $inventory.map |$item| { $item['name'] }
  $inventory_ips = $inventory.map |$item| { $item['ip'] }
  $cni_ranges_v4 = nomad_cni::cni_ranges_v4($network, $ingress_names, $min_networks)
  $vxlan_id = seeded_rand(16777215, $network) + 1

  # allow traffic from the CNI network to the host
  nomad_cni::vxlan::firewall { "br${vxlan_id}": }

  # create the CNI systemd service
  service { "cni-id@${cni_name}.service":
    ensure  => running,
    enable  => true,
    require => Systemd::Unit_file['cni-id@.service'],
    notify  => Exec["${module_name} reload nomad service"];
  }

  # create and run Bridge FDB script
  concat { "${vxlan_dir}/unicast-bridge-fdb.d/${cni_name}-bridge-fdb.sh":
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File["${vxlan_dir}/unicast.d/${cni_name}.sh"],
    notify  => Exec["populate bridge fdb for ${cni_name}"];
  }

  concat::fragment { "vxlan_${vxlan_id}_header":
    target => "${vxlan_dir}/unicast-bridge-fdb.d/${cni_name}-bridge-fdb.sh",
    source => "puppet:///modules/${module_name}/unicast-bridge-fdb-header.sh",
    order  => '0001',
  }

  $agents_pretty_inventory.each |$ingress| {
    concat::fragment { "vxlan_${vxlan_id}_${ingress['name']}":
      target  => "${vxlan_dir}/unicast-bridge-fdb.d/${cni_name}-bridge-fdb.sh",
      content => epp(
        "${module_name}/unicast-bridge-fdb.sh.epp", {
          ingress_mac => $ingress['mac'],
          ingress_ip  => $ingress['ip'],
          vxlan_id    => $vxlan_id,
          nolearning  => $nolearning,
        }
      ),
      order   => seeded_rand(20000, "vxlan_${vxlan_id}_${ingress['ip']}"),
    }
  }

  exec { "populate bridge fdb for ${cni_name}":
    command     => "${vxlan_dir}/unicast-bridge-fdb.d/${cni_name}-bridge-fdb.sh",
    refreshonly => true;
  }

  # == create CNI config file, collect all the fragments for the script and add the footer
  #
  $cni_ranges_v4.each |$cni_item| {
    $br_mac_address = nomad_cni::generate_mac("${cni_item[1]}${facts['networking']['hostname']}")
    $vxlan_mac_address = nomad_cni::generate_mac("${cni_item[1]}${cni_item[4]}${facts['networking']['hostname']}")
    if $cni_item[0] == $facts['networking']['hostname'] {
      file { "${vxlan_dir}/unicast.d/${cni_name}.sh":
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => File["${vxlan_dir}/unicast.d"],
        content => epp(
          "${module_name}/unicast-vxlan.sh.epp", {
            agent_ip          => $facts['networking']['interfaces'][$iface]['ip'],
            vxlan_id          => $vxlan_id,
            vxlan_ip          => $cni_item[1],
            iface             => $iface,
            vxlan_netmask     => $cni_item[4],
            nolearning        => $nolearning,
            cni_name          => $cni_name,
            br_mac_address    => $br_mac_address,
            vxlan_mac_address => $vxlan_mac_address,
          }
        );
      }
    }
  }
}
# vim: set ts=2 sw=2 et :
