# == Define: nomad_cni::vxlan::v4
#
# configure CNI and Unicast VXLAN/Bridge for Nomad
#
# == Parameters
#
# [*cni_name*] String
#   the name of the CNI
#
# [*network*] Stdlib::IP::Address::V4::CIDR
#   Network and Mask for the CNI
#
# [*agent_regex*] String
#   (requires PuppetDB) a string that match the hostnames of the Nomad agents (use either agent_list or agent_regex)
#
# [*agent_list*] Array
#   a list of the Nomad agents (use either agent_list or agent_regex)
#
# [*iface*] String
#   network interface on the Nomad agents
#
# [*cni_proto_version*] String
#   version of the CNI protocol
#
# [*nolearning*] Boolean
#   disable learning of MAC addresses on the bridge interface
#   DID NOT WORK AS EXPECTED. It may require testing and maybe an improved configuration
#
# [*min_networks*] Optional[Integer]
#   minimum number of networks to be created. If the number of agents is less than this number, the module will fail
#   check the README file for more details
#
define nomad_cni::vxlan::v4 (
  Variant[
    Array[Stdlib::IP::Address::V4::CIDR, 1],
    Array[Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR], 2]
  ] $vip_address,
  Stdlib::IP::Address::V4::CIDR $network,
  String $cni_name                = $name,
  Optional[String] $agent_regex   = undef,
  Array $agent_list               = [],
  String $iface                   = 'eth0',
  String $cni_proto_version       = '1.0.0',
  Boolean $nolearning             = false,  # please read the docs carefully before enabling this option
  Optional[Integer] $min_networks = undef,
  Optional[String] $ingress_regex = undef,
  Array $ingress_list             = [],
) {
  # == ensure that nomad_cni class was included and that the name is not reserved
  #
  unless defined(Class['nomad_cni']) {
    fail('nomad_cni::vxlan::v4 requires nomad_cni')
  }
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
  }
  elsif $agent_list != [] and !empty($agent_regex) {
    fail('Only one of agent_list or agent_regex can be set')
  }
  elsif $agent_list != [] {
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

  $vxlan_dir = '/opt/cni/vxlan'
  $agent_names = $agents_pretty_inventory.map |$item| { $item['name'] }
  $agent_ips = $agents_pretty_inventory.map |$item| { $item['ip'] }
  $cni_ranges_v4 = nomad_cni::cni_ranges_v4($network, $agent_names, $min_networks)
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

  $agents_pretty_inventory.each |$agent| {
    concat::fragment { "vxlan_${vxlan_id}_${agent['name']}":
      target  => "${vxlan_dir}/unicast-bridge-fdb.d/${cni_name}-bridge-fdb.sh",
      content => epp(
        "${module_name}/unicast-bridge-fdb.sh.epp", {
          agent_mac  => $agent['mac'],
          agent_ip   => $agent['ip'],
          vxlan_id   => $vxlan_id,
          nolearning => $nolearning,
        }
      ),
      order   => seeded_rand(20000, "vxlan_${vxlan_id}_${agent['ip']}"),
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
        require => File["${vxlan_dir}/unicast.d", "/opt/cni/config/${cni_name}.conflist"],
        notify  => Service["cni-id@${cni_name}.service"],
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
      file { "/opt/cni/config/${cni_name}.conflist":
        mode         => '0644',
        validate_cmd => "/usr/local/bin/cni-validator.rb --cidr ${network} --conf-file /opt/cni/config/${cni_name}.conflist --tmp-file %",
        require      => [
          File['/opt/cni/config', '/usr/local/bin/cni-validator.rb', '/run/cni'],
          Package['docopt']
        ],
        notify       => Service["cni-id@${cni_name}.service"],
        content      => to_json_pretty(
          {
            cniVersion => $cni_proto_version,
            name       => $cni_name,
            plugins    => [
              {
                type => 'loopback'
              },
              {
                type             => 'macvlan',
                master           => "br${vxlan_id}",
                isDefaultGateway => false,
                forceAddress     => false,
                ipMasq           => true,
                ipam             => {
                  type    => 'host-local',
                  ranges  => [
                    [
                      {
                        subnet     => $network,
                        rangeStart => $cni_item[2],
                        rangeEnd   => $cni_item[3],
                        gateway    => $cni_item[1]
                      },
                    ]
                  ],
                  routes  => [
                    {
                      dst => '0.0.0.0/0',
                      gw  => $cni_item[1]
                    },
                  ],
                  dataDir => '/run/cni/ipam-state',
                },
              },
              {
                type                   => 'firewall',
                backend                => 'iptables',
                iptablesAdminChainName => 'NOMAD-ADMIN'
              },
              {
                type         => 'portmap',
                capabilities => {
                  portMappings => true,
                },
                snat         => true
              },
            ],
          }
        ),
      }
    }
  }
}
# vim: set ts=2 sw=2 et :
