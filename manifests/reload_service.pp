# Class: nomad_cni::reload_service
#
#
class nomad_cni::reload_serv {
  # == this is a private class
  #
  assert_private()

  exec { "${module_name} reload nomad service":
    path        => ['/bin', '/usr/bin'],
    command     => 'systemctl reload nomad',
    refreshonly => true,
  }
}
