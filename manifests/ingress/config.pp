# Class: nomad_cni::ingress::config
#
# This class installs the CNI plugins and python3-demjson
#
# == Parameters
#
# [*keep_vxlan_up_timer_interval*] Integer
# interval in minutes to run systemdd timer job to keep VXLANs up
#
# [*keep_vxlan_up_timer_unit*] Enum['usec', 'msec', 'seconds', 'minutes', 'hours', 'days', 'weeks', 'months', 'years']
# timer unit for the time interval: default minutes
#
class nomad_cni::ingress::config (
  Integer $keep_vxlan_up_timer_interval,
  Enum['usec', 'msec', 'seconds', 'minutes', 'hours', 'days', 'weeks', 'months', 'years'] $keep_vxlan_up_timer_unit
) {
  # this is a private class
  assert_private()

  unless defined(Package['bridge-utils']) { package { 'bridge-utils': ensure => present } }

  # == create necessary files
  #
  file {
    default:
      owner => 'root',
      group => 'root',
      mode  => '0755';
    '/opt/cni':
      ensure => directory;
    ['/opt/cni/vxlan', '/opt/cni/vxlan/unicast-bridge-fdb.d', '/opt/cni/vxlan/unicast.d']:
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true;
    '/usr/local/bin/cni-vxlan-wizard.sh':
      source => "puppet:///modules/${module_name}/cni-vxlan-wizard.sh";
  }

  # == purge unused VXLANs (triggered by directory changes)
  #
  exec { 'purge_unused_vxlans':
    command     => 'flock /tmp/cni-vxlan-wizard cni-vxlan-wizard.sh --purge',
    require     => File['/usr/local/bin/cni-vxlan-wizard.sh'],
    path        => ['/usr/local/bin', '/usr/bin'],
    refreshonly => true,
    subscribe   => File['/opt/cni/vxlan/unicast.d'];
  }

  unless defined(Package['fping']) { package { 'fping': ensure => present } }

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
          keep_vxlan_up_timer_interval => $keep_vxlan_up_timer_interval,
          keep_vxlan_up_timer_unit     => $keep_vxlan_up_timer_unit,
        }
      );
  }

  service { 'cni-purge.timer':
    ensure    => running,
    subscribe => Systemd::Timer['cni-purge.timer'],
    enable    => true;
  }
}
# vim: set ts=2 sw=2 et :
