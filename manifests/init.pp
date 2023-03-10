# == Class: nomad_cni
#
#
# == Paramters:
#
# [*cni_version*] String
# version of CNI to install
#
# [*cni_base_url*] Stdlib::HTTPSUrl
# URL to download CNI plugins from
#
# [*manage_rc_local*] Boolean
# Create startup script to setup VXLANs on boot
#
class nomad_cni (
  String $cni_version = $nomad_cni::params::cni_version,
  Stdlib::HTTPSUrl $cni_base_url = $nomad_cni::params::cni_base_url,
  Boolean $manage_rc_local = $nomad_cni::params::manage_rc_local,
) inherits nomad_cni::params {
  include nomad_cni::files

  class { 'nomad_cni::install':
    cni_version  => $cni_version,
    cni_base_url => $cni_base_url,
  }

  if ($manage_rc_local) {
    incldue nomad_cni::rc_local
  }

  cron { 'run-all-vxlan-scripts':
    command => '/usr/bin/run-parts /opt/vxlan --arg=--all',
    user    => 'root',
    hour    => '*',
    minute  => '*/10',
  }
}
