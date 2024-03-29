# == Define: nomad_cni::macvlan::multicast::v4
#
# configure CNI and Multicast VXLAN/Bridge for Nomad
#
# == Parameters
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
# [*min_networks*] Optional[Integer]
#   minimum number of networks to be created. If the number of agents is less than this number, the module will fail
#   check the README file for more details
#
define nomad_cni::macvlan::multicast::v4 (
  Stdlib::IP::Address::V4::CIDR $network,
  String $cni_name                = $name,
  Optional[String] $agent_regex   = undef,
  Array $agent_list               = [],
  String $iface                   = 'eth0',
  String $cni_proto_version       = '1.0.0',
  Optional[Integer] $min_networks = undef,
) {
  # == ensure that nomad_cni class was included and that the name is not reserved
  #
  unless defined(Class['nomad_cni']) {
    fail('nomad_cni::macvlan::multicast::v4 requires nomad_cni')
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
    $agent_names = puppetdb_query(
      "inventory[facts.networking.hostname] {
        facts.networking.hostname ~ '${agent_regex}' and facts.agent_specified_environment = '${facts['agent_specified_environment']}'
      }"
    ).map |$item| { $item['facts.networking.hostname'] }
  }

  $cni_ranges_v4 = nomad_cni::cni_ranges_v4($network, $agent_names, $min_networks)
  $vxlan_id = seeded_rand(16777215, $network) + 1
  $multicast_group = nomad_cni::int_to_v4(seeded_rand(268435455, $network) + 1)

  # == create the CNI systemd service
  #
  service { "cni-id@${cni_name}.service":
    ensure  => running,
    enable  => true,
    require => Systemd::Unit_file['cni-id@.service'],
    notify  => Exec["${module_name} reload nomad service"];
  }

  # == create CNI config file and VXLAN script
  #
  $cni_ranges_v4.each |$cni_item| {
    if $cni_item[0] == $facts['networking']['hostname'] {
      file { "/opt/cni/vxlan/multicast.d/${cni_name}.sh":
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => File['/opt/cni/vxlan/multicast.d', "/opt/cni/config/${cni_name}.conflist"],
        content => epp(
          "${module_name}/multicast-vxlan.sh.epp", {
            vxlan_id        => $vxlan_id,
            vxlan_ip        => $cni_item[1],
            iface           => $iface,
            multicast_group => $multicast_group,
            vxlan_netmask   => $cni_item[4],
          }
        ),
        notify  => Service["cni-id@${cni_name}.service"];
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
