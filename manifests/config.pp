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
# [*keep_vxlan_up_cron_ensure*] Boolean
# install cron job to keep VXLANs up
#
# [*keep_vxlan_up_cron_interval*] Integer[1, 59]
# interval in minutes to run cron job to keep VXLANs up
#
class nomad_cni::config (
  String $cni_version,
  Variant[Stdlib::HTTPSUrl, Stdlib::HTTPSUrl] $cni_base_url,
  Boolean $keep_vxlan_up_cron_ensure,
  Integer[1, 59] $keep_vxlan_up_cron_interval
) {
  # == this is a private class
  #
  assert_private()

  # == create necessary files
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
      notify => Service['vxlan-configurator.service'],
      source => "puppet:///modules/${module_name}/vxlan-configurator.sh";
  }

  # == purge unused VXLANs
  #
  exec { 'purge_unused_vxlans':
    command     => 'flock /tmp/vxlan-configurator vxlan-configurator.sh --purge',
    require     => File['/usr/local/bin/vxlan-configurator.sh'],
    path        => ['/usr/local/bin', '/bin', '/usr/bin', '/sbin', '/usr/sbin'],
    refreshonly => true,
    subscribe   => File['/etc/cni/vxlan.d'];
  }

  # == install python3-demjson and fping
  #
  $packages = ['python3-demjson', 'fping']
  $packages.each |String $package| {
    unless defined(Package[$package]) {
      package { $package: ensure => present, }
    }
  }

  # == install CNI plugins
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

  # == create startup service for VXLAN configurator
  #
  systemd::unit_file { 'vxlan-configurator.service':
    source => "puppet:///modules/${module_name}/vxlan-configurator.service",
    notify => Service['vxlan-configurator.service'];
  }
  service { 'vxlan-configurator.service':
    ensure => running,
    enable => true,
  }

  # == create cron job to keep the VXLAN up
  #
  $cron_ensure_status = $keep_vxlan_up_cron_ensure ? {
    true  => present,
    false => absent,
  }
  cron {
    default:
      user     => 'root',
      hour     => '*',
      month    => '*',
      monthday => '*',
      weekday  => '*';
    'keep-vxlan-up':
      ensure  => $cron_ensure_status,
      command => 'flock /tmp/vxlan-configurator /usr/local/bin/vxlan-configurator.sh --all',
      minute  => "*/${$keep_vxlan_up_cron_interval}";
    'purge_unused_vxlans':
      ensure  => present,
      user    => 'root',
      command => 'flock /tmp/vxlan-configurator /usr/local/bin/vxlan-configurator.sh --purge',
      minute  => fqdn_rand(59);
  }
}
# vim: set ts=2 sw=2 et :
