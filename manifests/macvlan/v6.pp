# == Define: nomad_cni::macvlan::v6
#
# configure CNI and VXLAN/Bridge for Nomad
#
# == Paramters:
#
# [*cni_name*] String
# the name of the CNI
#
define nomad_cni::macvlan::v6 (
  String $cni_name = $name
) {
  # == place-holder
  #
  notify { "nomad_cni::macvlan::v6 ${name}":
    message => "this is a place-holder. It's not yet implemented"
  }
}
