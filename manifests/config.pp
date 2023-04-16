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
# [*keep_vxlan_up_cron_interval*] Integer[1, 59]
# interval in minutes to run cron job to keep VXLANs up
#
class nomad_cni::config (
  String $cni_version,
  Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl] $cni_base_url,
  Integer[1, 59] $keep_vxlan_up_cron_interval
) {
  # == this is a private class
  #
  assert_private()

  $cni_directories = [
    '/opt/cni/config', '/opt/cni/vxlan',
    '/opt/cni/vxlan/unicast_bridge_fdb.d',
    '/opt/cni/vxlan/unicast.d',
    '/opt/cni/vxlan/multicast.d'
  ]

  # == create necessary files
  #
  file {
    default:
      owner => 'root',
      group => 'root',
      mode  => '0755';
    ['/opt/cni', '/opt/cni/bin', '/run/cni']:
      ensure => directory;
    $cni_directories:
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true;
    '/usr/local/bin/cni-validator.sh':
      source => "puppet:///modules/${module_name}/cni-validator.sh";
    '/usr/local/bin/vxlan-wizard.sh':
      source => "puppet:///modules/${module_name}/vxlan-wizard.sh";
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
    command     => 'flock /tmp/vxlan-wizard vxlan-wizard.sh --purge',
    require     => File['/usr/local/bin/vxlan-wizard.sh'],
    path        => ['/usr/local/bin', '/usr/bin'],
    refreshonly => true,
    subscribe   => File['/opt/cni/vxlan/unicast.d', '/opt/cni/vxlan/multicast.d'];
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

  systemd::timer {
    'cni-purge.timer':  # get rid of unused VXLANs
      service_source => "puppet:///modules/${module_name}/cni-purge.service",
      timer_source   => "puppet:///modules/${module_name}/cni-purge.timer";
    'cni-up.timer':  # ensure that the VXLANs are up and running
      service_source => "puppet:///modules/${module_name}/cni-up.service",
      timer_content  => epp(
        "${module_name}/cni-up.timer.epp", {
          keep_vxlan_up_cron_interval => $keep_vxlan_up_cron_interval,
        }
      );
  }

  service {
    'cni-purge.timer':
      ensure    => running,
      subscribe => Systemd::Timer['cni-purge.timer'];
    'cni-up.timer':
      ensure    => running,
      subscribe => Systemd::Timer['cni-up.timer'];
  }
}
# vim: set ts=2 sw=2 et :
