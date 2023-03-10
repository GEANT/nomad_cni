# Class: nomad_cni::rc_local
#
#
class nomad_cni::rc_local {
  assert_private()

  file {
    '/etc/rc.local':
      ensure => link,
      target => 'rc.d/rc.local';
    '/etc/rc.d/rc.local':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      source => 'puppet:///modules/nomad_cni/rc.local';
  }

  service { 'rc-local.service':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    provider   => 'systemd',
    require    => File['/etc/rc.d/rc.local'];
  }
}
