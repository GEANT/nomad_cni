# Class: nomad_cni::config
#
# This class installs the CNI plugins and python3-demjson
#
# == Paramters:
#
# [*cni_version*] String
# version of CNI to install
#
# [*cni_base_url*] Stdlib::HTTPSUrl
# URL to download CNI plugins from
#
# [*manage_startup_script*] Boolean
# Create startup script through rc.local to setup VXLANs on boot
#
# [*keep_vxlan_up_cron_ensure*] Boolean
# install cron job to keep VXLANs up
#
# [*keep_vxlan_up_cron_interval*] Integer[1, 59]
# interval in minutes to run cron job to keep VXLANs up
#
class nomad_cni::config (
  String $cni_version,
  Stdlib::HTTPSUrl $cni_base_url,
  Boolean $manage_startup_script,
  Boolean $keep_vxlan_up_cron_ensure,
  Integer[1, 59] $keep_vxlan_up_cron_interval
) {
  # this is a private class
  assert_private()

  # create necessary files
  #
  file {
    default:
      owner => 'root',
      group => 'root',
      mode  => '0755';
    ['/opt/cni', '/opt/cni/bin', '/run/cni', '/etc/cni']:
      ensure => directory;
    ['/opt/cni/config', '/etc/cni/vxlan.d']:
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true;
    '/usr/local/bin/cni-validator.sh':
      source => "puppet:///modules/${module_name}/cni-validator.sh";
    '/usr/local/bin/vxlan-configurator.sh':
      source => "puppet:///modules/${module_name}/vxlan-configurator.sh";
  }

  # == purge unused VXLANs
  exec { 'purge_unused_vxlans':
    command     => '/usr/local/bin/vxlan-configurator.sh --purge',
    require     => File['/usr/local/bin/vxlan-configurator.sh'],
    refreshonly => true,
    subscribe   => File['/etc/cni/vxlan.d'];
  }

  # install python3-demjson and fping
  #
  $packages = ['python3-demjson', 'fping']
  $packages.each |String $package| {
    unless defined(Package[$package]) {
      package { $package: ensure => present, }
    }
  }

  # install CNI plugins
  #
  exec { 'remove_old_cni':
    command => 'rm -f /opt/cni/bin/*',
    unless  => "test -f /opt/cni/bin/bridge && /opt/cni/bin/bridge 2>&1 | awk -F' v' '/plugin/{print \$NF}' | grep -w \"${cni_version}\"",
    path    => '/usr/bin';
  }
  archive { "/tmp/cni-plugins-linux-amd64-v${cni_version}.tgz":
    ensure        => present,
    cleanup       => true,
    extract       => true,
    extract_path  => '/opt/cni/bin',
    source        => "${cni_base_url}/v${cni_version}/cni-plugins-linux-amd64-v${cni_version}.tgz",
    creates       => '/opt/cni/bin/bridge',
    checksum_url  => "${cni_base_url}/v${cni_version}/cni-plugins-linux-amd64-v${cni_version}.tgz.sha256",
    checksum_type => 'sha256',
    require       => [File['/opt/cni/bin'], Exec['remove_old_cni']];
  }

  # create startup script
  #
  if ($manage_startup_script) {
    file {
      '/etc/rc.d/rc.local':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => "puppet:///modules/${module_name}/rc.local";
      '/etc/rc.local':
        ensure => link,
        target => 'rc.d/rc.local';
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

  # create cron job to keep vxlan up
  #
  $cron_ensure_status = $keep_vxlan_up_cron_ensure ? {
    true  => present,
    false => absent,
  }
  cron {
    'keep-vxlan-up':
      ensure  => $cron_ensure_status,
      command => 'flock /tmp/vxlan-configurator /usr/local/bin/vxlan-configurator.sh --all',
      user    => 'root',
      hour    => '*',
      minute  => "*/${$keep_vxlan_up_cron_interval}";
    'purge_unused_vxlans':
      ensure  => present,
      user    => 'root',
      command => 'flock /tmp/vxlan-configurator /usr/local/bin/vxlan-configurator.sh --purge',
      hour    => [fqdn_rand(6), fqdn_rand(6) + 6, fqdn_rand(6) + 12, fqdn_rand(6) + 18];
  }
}
# vim: set ts=2 sw=2 et :
