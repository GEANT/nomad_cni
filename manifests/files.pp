# Class: nomad_cni::files
#
#
class nomad_cni::files {
  assert_private()

  file { ['/opt/cni', '/opt/cni/bin', '/opt/vxlan', '/run/cni', '/etc/cni', '/etc/cni/vlxlan.d']:
    ensure => directory;
  }

  file {
    '/opt/cni/config':
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true;
    '/usr/local/bin/cni-validator.sh':
      mode   => '0755',
      source => "puppet:///modules/${module_name}/cni-validator.sh";
    '/usr/local/bin/vxlan-configurator.sh':
      mode   => '0755',
      source => "puppet:///modules/${module_name}/vxlan-configurator.sh";
  }
}
