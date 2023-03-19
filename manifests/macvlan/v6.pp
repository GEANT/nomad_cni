# == Define: nomad_cni::macvlan::v6
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
# [*network*] Stdlib::IP::Address::V6::CIDR
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
define nomad_cni::macvlan::v6 (
  Stdlib::IP::Address::V6::CIDR $network,
  Array[Stdlib::IP::Address::Nosubnet] $dns_servers,
  Array[Stdlib::Fqdn] $dns_search_domains,
  Stdlib::Fqdn $dns_domain,
  String $cni_name             = $name,
  String $agent_regex          = undef,
  Array $agent_list            = [],
  String $iface                = 'eth0',
  String $cni_protocol_version = '1.0.0',
) {
  # == place-holder
  #
  notify { "nomad_cni::macvlan::v6 ${name}":
    message => "this is a place-holder. It's not yet implemented"
  }
}
