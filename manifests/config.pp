# Class: nomad_cni::config
#
# This class installs the CNI plugins and python3-demjson
#
# == Paramters:
#
# [*cni_version*] String
# version of CNI to install
#
# [*cni_base_url*] Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl]
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
  Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl] $cni_base_url,
  Boolean $keep_vxlan_up_cron_ensure,
  Integer[1, 59] $keep_vxlan_up_cron_interval
) {
  # == this is a private class
  #
  assert_private()

  # == include dependencies
  #
  include nomad_cni::reload_service

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
      source => "puppet:///modules/${module_name}/vxlan-configurator.sh";
  }

  # == define Nomad service reload
  #
  exec { "${module_name} reload nomad service":
    path        => ['/bin', '/usr/bin'],
    command     => 'systemctl reload nomad',
    refreshonly => true,
  }

  # == purge unused VXLANs (triggered by directory changes)
  #
  exec { 'purge_unused_vxlans':
    command     => 'flock /tmp/vxlan-configurator vxlan-configurator.sh --purge',
    require     => File['/usr/local/bin/vxlan-configurator.sh'],
    path        => ['/usr/local/bin', '/usr/bin'],
    refreshonly => true,
    subscribe   => File['/etc/cni/vxlan.d'];
  }

  # == install python3-demjson and fping
  #
  ['python3-demjson', 'fping'].each |String $package| {
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

  # == create systemd unit file
  #
  systemd::unit_file { 'cni-id@.service':
    source => "puppet:///modules/${module_name}/cni-id.service";
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
    # ensure that the VXLANs are up and running (ideally this should be done by systemd)  (FIXME)
    'keep-vxlan-up':
      ensure  => $cron_ensure_status,
      command => 'flock /tmp/vxlan-configurator /usr/local/bin/vxlan-configurator.sh --status up --name all',
      minute  => "*/${$keep_vxlan_up_cron_interval}";
    # it unconfigures the VXLANs that are not in use and disable corresponding systemd services
    # it's also triggered when the directory /etc/cni/vxlan.d is changed
    'purge_unused_vxlans':
      ensure  => present,
      user    => 'root',
      command => 'flock /tmp/vxlan-configurator /usr/local/bin/vxlan-configurator.sh --purge',
      minute  => fqdn_rand(59);
  }
}
# vim: set ts=2 sw=2 et :
