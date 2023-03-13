# == Define: nomad_cni::macvlan_v4
#
# configure CNI and VXLAN/Bridge for Nomad
#
# == Paramters:
#
# [*cni_name*] String
# the name of the CNI
#
# [*dns_servers*] Array[Stdlib::IP::Address::Nosubnet]
# DNS servers for the CNI
#
# [*dns_search_domains*] Array[Stdlib::Fqdn]
# DNS domain search list
#
# [*dns_domain*] Stdlib::Fqdn
# DNS domain
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
# [*cni_protocol_version*] String
# version of the CNI configuration
#
define nomad_cni::macvlan_v4 (
  Stdlib::IP::Address::V4::CIDR $network,
  Array[Stdlib::IP::Address::Nosubnet] $dns_servers,
  Array[Stdlib::Fqdn] $dns_search_domains,
  Stdlib::Fqdn $dns_domain,
  String $cni_name             = $name,
  String $agent_regex          = undef,
  Array $agent_list            = [],
  String $iface                = 'eth0',
  String $cni_protocol_version = '1.0.0',
) {
  # == ensure that nomad_cni class was included
  #
  unless defined(Class['nomad_cni']) {
    fail('nomad_cni::macvlan_v4 requires nomad_cni')
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
    $agent_names = puppetdb_query(
      "inventory[facts.hostname] {
        facts.hostname ~ '${agent_regex}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
      }"
    ).map |$item| { $item['facts.hostname'] }
  }
  $cni_ranges_v4 = nomad_cni::cni_ranges_v4($network, $agent_names)
  $vxlan_id = seeded_rand(16777215, $network) + 1

  exec { "vxlan${vxlan_id}":
    command     => "flock /tmp/vxlan-configurator /usr/local/bin/vxlan-configurator.sh -f -i ${vxlan_id}",
    require     => File['/usr/local/bin/vxlan-configurator.sh'],
    refreshonly => true,
  }

  concat { "/etc/cni/vxlan.d/vxlan${vxlan_id}.conf":
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => File['/etc/cni/vxlan.d'],
    notify  => Exec["vxlan${vxlan_id}"];
  }

  @@concat::fragment { "vxlan_${vxlan_id}_${facts['networking']['hostname']}":
    tag     => "nomad_vxlan_${vxlan_id}_${facts['agent_specified_environment']}",
    target  => "/etc/cni/vxlan.d/vxlan${vxlan_id}.conf",
    content => "\"${facts['networking']['ip']}\"\n",
    order   => seeded_rand(2000, "vxlan_${vxlan_id}_${facts['networking']['ip']}");
  }

  # == create CNI config file, collect all the fragments for the script and add the footer
  #
  $cni_ranges_v4.each |$cni_item| {
    if $cni_item[0] == $facts['networking']['hostname'] {
      concat::fragment {
        "vxlan_${vxlan_id}_header":
          target  => "/etc/cni/vxlan.d/vxlan${vxlan_id}.conf",
          content => epp(
            "${module_name}/vxlan_header.conf.epp", {
              vxlan_id      => $vxlan_id,
              vxlan_ip      => $cni_item[1],
              iface         => $iface,
              vxlan_netmask => $cni_item[4]
            }
          ),
          order   => '0001';
        "vxlan_${vxlan_id}_footer":
          target  => "/etc/cni/vxlan.d/vxlan${vxlan_id}.conf",
          content => ")\nexport vxlan_id vxlan_ip vxlan_netmask iface remote_ip_array\n",
          order   => 'zzzz';
      }
      file { "/opt/cni/config/${cni_name}.conflist":
        mode         => '0644',
        validate_cmd => "/usr/local/bin/cni-validator.sh -n ${network} -f /opt/cni/config/${cni_name}.conflist -t %",
        require      => [
          File['/opt/cni/config', '/usr/local/bin/cni-validator.sh', '/run/cni'],
          Package['python3-demjson']
        ],
        content      => to_json_pretty(
          {
            cniVersion => $cni_protocol_version,
            name       => $cni_name,
            plugins    => [
              {
                type => 'loopback'
              },
              {
                type             => 'macvlan',
                master           => "vxlan${vxlan_id}",
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
                  dns     => {
                    nameservers => $dns_servers,
                    domain      => $dns_domain,
                    search      => $dns_search_domains,
                  },
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
    } else {
      Concat::Fragment <<|
        title == "vxlan_${vxlan_id}_${$cni_item[0]}" and
        tag == "nomad_vxlan_${vxlan_id}_${facts['agent_specified_environment']}"
      |>>
    }
  }
}
# vim: set ts=2 sw=2 et :
