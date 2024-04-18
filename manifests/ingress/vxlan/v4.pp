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
  } elsif $agent_list != [] and empty($agent_regex) {
    $agent_names = $agent_list
    $agent_inventory = $agent_names.map |$item| {
      $item_inventory = puppetdb_query(
        "inventory[facts.networking.hostname, facts.networking.interfaces.${iface}.ip, facts.networking.interfaces.${iface}.mac] {
          facts.networking.hostname = '${item}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
        }"
      )
    }
  } else {
    $agent_inventory = puppetdb_query(
      "inventory[facts.networking.hostname, facts.networking.interfaces.${iface}.ip, facts.networking.interfaces.${iface}.mac] {
        facts.networking.hostname ~ '${agent_regex}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
      }"
    )
  }
  $agent_pretty_inventory = $agent_inventory.map |$item| {
    {
      'name' => $item['facts.networking.hostname'],
      'ip' => $item["facts.networking.interfaces.${iface}.ip"],
      'mac' => $item["facts.networking.interfaces.${iface}.mac"]
    }
  }

  if $ingress_vip =~ Stdlib::IP::Address::V4::Nosubnet {
    $vip_address = $ingress_vip
  } else {
    $vip_address = dnsquery::a($ingress_vip)[0]
  }

  $vxlan_dir = '/opt/cni/vxlan'
  $vxlan_id = seeded_rand(16777215, $network) + 1
  if ($nolearning) {
    # this is not yet covered by the module
    $vip_bridge_fdb = "bridge fdb append ${facts['networking']['interfaces'][$iface]['mac']} dev vx${vxlan_id} dst ${vip_address}\n"
  } else {
    $vip_bridge_fdb = "bridge fdb append 00:00:00:00:00:00 dev vx${vxlan_id} dst ${vip_address}\n"
  }

  # allow traffic from the CNI network to the host
  nomad_cni::vxlan::firewall { "br${vxlan_id}": }

  # create the CNI systemd service
  service { "cni-id@${cni_name}.service":
    ensure  => running,
    enable  => true,
    require => Systemd::Unit_file['cni-id@.service'];
  }

  # create and run Bridge FDB script
  concat { "${vxlan_dir}/unicast-bridge-fdb.d/${cni_name}-bridge-fdb.sh":
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File["${vxlan_dir}/unicast.d/${cni_name}.sh"],
    notify  => Exec["populate bridge fdb for ${cni_name}"];
  }

  concat::fragment {
    default:
      target => "${vxlan_dir}/unicast-bridge-fdb.d/${cni_name}-bridge-fdb.sh";
    "vxlan_${vxlan_id}_header":
      source => "puppet:///modules/${module_name}/unicast-bridge-fdb-header.sh",
      order  => '0001';
    "vxlan_${vxlan_id}_vip":
      content => $vip_bridge_fdb,
      order   => '0002';
  }

  $agent_pretty_inventory.each |$item| {
    concat::fragment { "vxlan_${vxlan_id}_${item['name']}":
      target  => "${vxlan_dir}/unicast-bridge-fdb.d/${cni_name}-bridge-fdb.sh",
      content => epp("${module_name}/unicast-bridge-fdb.sh.epp",
        {
          agent_mac  => $item['mac'],
          agent_ip   => $item['ip'],
          vxlan_id   => $vxlan_id,
          nolearning => $nolearning,
        }
      ),
      order   => seeded_rand(20000, "vxlan_${vxlan_id}_${item['ip']}"),
    }
  }

  exec { "populate bridge fdb for ${cni_name}":
    command     => "${vxlan_dir}/unicast-bridge-fdb.d/${cni_name}-bridge-fdb.sh",
    refreshonly => true;
  }

  # == create CNI config file, collect all the fragments for the script and add the footer
  #
  $vxlan_ingress = nomad_cni::cni_ingress_v4($network)
  $vxlan_netmask = $network.split('/')[1]
  $br_mac_address = nomad_cni::generate_mac("${vxlan_ingress[1]}${vip_address}")
  $vxlan_mac_address = nomad_cni::generate_mac("${vxlan_ingress[1]}${vxlan_netmask}${vip_address}")
  file {
    default:
      owner   => 'root',
      group   => 'root',
      notify  => Service["cni-id@${cni_name}.service"],
      require => File["${vxlan_dir}/unicast.d"];
    "${vxlan_dir}/unicast.d/${cni_name}.conf":
      mode    => '0644',
      content => epp("${module_name}/unicast-vxlan.conf.epp",
        {
          vxlan_id          => $vxlan_id,
          vxlan_ip          => $vxlan_ingress[1],
          network           => $network,
          vxlan_netmask     => $vxlan_netmask,
        }
      );
    "${vxlan_dir}/unicast.d/${cni_name}.sh":
      mode    => '0755',
      content => epp("${module_name}/unicast-vxlan.sh.epp",
        {
          is_keepalived     => 'BOFH',
          agent_ip          => $vip_address,
          vxlan_id          => $vxlan_id,
          vxlan_ip          => $vxlan_ingress[1],
          vxlan_net         => $vxlan_ingress[0],
          iface             => $iface,
          vxlan_netmask     => $vxlan_netmask,
          nolearning        => $nolearning,
          cni_name          => $cni_name,
          br_mac_address    => $br_mac_address,
          vxlan_mac_address => $vxlan_mac_address,
        }
      );
  }
}
# vim: set ts=2 sw=2 et :
