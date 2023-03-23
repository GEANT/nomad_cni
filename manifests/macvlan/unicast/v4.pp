# == Define: nomad_cni::macvlan::unicast::v4
#
# configure CNI and VXLAN/Bridge for Nomad
#
# == Paramters:
#
# [*cni_name*] String
# the name of the CNI
#
# [*network*] Stdlib::IP::Address::V4::CIDR
# Network and Mask for the CNI
#
# [*agent_regex*] String
# (requires PuppetDB) a string that match the hostnames of the Nomad agents (use either agent_list or agent_regex)
#
# [*agent_list*] Array
# a list of the Nomad agents  (use either agent_list or agent_regex)
#
# [*iface*] String
# network interface on the Nomad agents
#
# [*cni_proto_version*] String
# version of the CNI protocol
#
define nomad_cni::macvlan::unicast::v4 (
  Stdlib::IP::Address::V4::CIDR $network,
  String $cni_name          = $name,
  String $agent_regex       = undef,
  Array $agent_list         = [],
  String $iface             = 'eth0',
  String $cni_proto_version = '1.0.0',
) {
  # == ensure that nomad_cni class was included and that the name is not reserved
  #
  unless defined(Class['nomad_cni']) {
    fail('nomad_cni::macvlan::v4 requires nomad_cni')
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
  }
  else {
    $agents_inventory = puppetdb_query(
      "inventory[facts.networking.hostname, facts.networking.interfaces.${iface}.ip, facts.networking.interfaces.${iface}.mac] {
        facts.networking.hostname ~ '${agent_regex}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
      }"
    )
    $agents_pretty_inventory = $agents_inventory.map |$item| {
      {
        'name' => $item['facts.networking.hostname'],
        'ip' => $item["facts.networking.interfaces.${iface}.ip"],
        'mac' => $item["facts.networking.interfaces.${iface}.mac"]
      }
    }
    $agent_names = $agents_inventory.map |$item| { $item['facts.networking.hostname'] }
  }
  $cni_ranges_v4 = nomad_cni::cni_ranges_v4($network, $agent_names)
  $vxlan_id = seeded_rand(16777215, $network) + 1

  $test = {
    'test1' => [ '$agent_names', '$cni_ranges_v4', '$vxlan_id' ],
  }

  service { "cni-id@${cni_name}.service":
    ensure  => running,
    enable  => true,
    require => Systemd::Unit_file['cni-id@.service'],
    notify  => Exec["${module_name} reload nomad service"];
  }

  concat { "/etc/vxlan/unicast.d/${cni_name}.sh":
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/etc/vxlan/unicast.d'],
    notify  => Service["cni-id@${cni_name}.service"];
  }

  $agents_pretty_inventory.each |$agent| {
    concat::fragment { "vxlan_${vxlan_id}_${agent['name']}":
      target  => "/etc/vxlan/unicast.d/${cni_name}.sh",
      content => epp(
        "${module_name}/bridge-fdb.epp", {
          agent_mac => $agent['mac'],
          agent_ip  => $agent['ip'],
          vxlan_id  => $vxlan_id,
        }
      ),
      order   => seeded_rand(20000, "vxlan_${vxlan_id}_${agent['ip']}");
    }
  }

  # == create CNI config file, collect all the fragments for the script and add the footer
  #
  $cni_ranges_v4.each |$cni_item| {
    if $cni_item[0] == $facts['networking']['hostname'] {
      concat::fragment {
        "vxlan_${vxlan_id}_header":
          target  => "/etc/vxlan/unicast.d/${cni_name}.sh",
          content => epp(
            "${module_name}/unicast-vxlan-script-header.sh.epp", {
              vxlan_id      => $vxlan_id,
              vxlan_ip      => $cni_item[1],
              iface         => $iface,
              vxlan_netmask => $cni_item[4]
            }
          ),
          order   => '0001';
        "vxlan_${vxlan_id}_footer":
          target  => "/etc/vxlan/unicast.d/${cni_name}.sh",
          content => epp(
            "${module_name}/unicast-vxlan-script-footer.sh.epp", {
              vxlan_id      => $vxlan_id,
              vxlan_ip      => $cni_item[1],
              vxlan_netmask => $cni_item[4]
            }
          ),
          order   => 'zzzz';
      }
      file { "/opt/cni/config/${cni_name}.conflist":
        mode         => '0644',
        validate_cmd => "/usr/local/bin/cni-validator.sh -n ${network} -f /opt/cni/config/${cni_name}.conflist -t %",
        require      => [
          File['/opt/cni/config', '/usr/local/bin/cni-validator.sh', '/run/cni'],
          Package['python3-demjson']
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
                master           => "vxbr${vxlan_id}",
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
