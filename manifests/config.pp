# Class: nomad_cni::config
#
# This class installs the CNI plugins and python3-demjson
#
# == Parameters
#
# [*ingress_vip*]
#   Array of proxy vip
#
# [*cni_version*] String
# version of CNI to install
#
# [*cni_base_url*] Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl]
# URL to download CNI plugins from
#
# [*keep_vxlan_up_timer_interval*] Integer
# interval in minutes to run systemdd timer job to keep VXLANs up
#
# [*keep_vxlan_up_timer_unit*] Enum['usec', 'msec', 'seconds', 'minutes', 'hours', 'days', 'weeks', 'months', 'years']
# timer unit for the time interval: default minutes
#
# [*install_dependencies*] Boolean
#   whether to install the dependencies or not: 'bridge-utils', 'ethtool', 'fping'
#
class nomad_cni::config (
  Variant[String, Array] $ingress_vip,
  String $cni_version,
  Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl] $cni_base_url,
  Integer $keep_vxlan_up_timer_interval,
  Enum['usec', 'msec', 'seconds', 'minutes', 'hours', 'days', 'weeks', 'months', 'years'] $keep_vxlan_up_timer_unit,
  Boolean $install_dependencies,
) {
  assert_private()

  $ipv4_only_vip_cidr = $ingress_vip ? {
    String => $ingress_vip,
    default => $ingress_vip.filter |$item| { $item !~ Stdlib::IP::Address::V6::CIDR }[0]
  }
  $ipv4_only_vip_address = $ipv4_only_vip_cidr.split('/')[0]
  $ipv4_only_vip_netmask = $ipv4_only_vip_cidr.split('/')[1]
  $cni_directories = [
    '/opt/cni/config', '/opt/cni/vxlan',
    '/opt/cni/vxlan/unicast-bridge-fdb.d',
    '/opt/cni/vxlan/unicast.d',
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
    '/usr/local/bin/cni-validator.sh':  # legacy
      ensure => absent;
    '/usr/local/bin/cni-validator.rb':
      source => "puppet:///modules/${module_name}/cni-validator.rb";
    '/usr/local/bin/cni-vxlan-wizard.sh':
      source => "puppet:///modules/${module_name}/cni-vxlan-wizard.sh";
    '/opt/cni/params.conf':
      mode    => '0644',
      content => epp("${module_name}/params.conf.epp",
        {
          ipv4_only_vip_address => $ipv4_only_vip_address,
          ipv4_only_vip_netmask => $ipv4_only_vip_netmask,
        }
      );
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
    command     => 'flock /tmp/cni-vxlan-wizard cni-vxlan-wizard.sh --purge',
    require     => File['/usr/local/bin/cni-vxlan-wizard.sh'],
    path        => ['/usr/local/bin', '/usr/bin'],
    refreshonly => true,
    subscribe   => File['/opt/cni/vxlan/unicast.d'];
  }

  # == install dependencies
  #
  if $install_dependencies {
    $bridge_pkg = $facts['os']['family'] ? {
      'Debian' => 'bridge-utils',
      'RedHat' => 'iproute',
    }
    [$bridge_pkg, 'ethtool', 'fping'].each |$pkg| {
      unless defined(Package[$pkg]) { package { $pkg: ensure => present } }
    }
    unless defined(Package['docopt']) {
      package { 'docopt':
        ensure   => present,
        provider => 'gem',
      }
    }
  }

  # == install CNI plugins
  #
  unless $facts['nomad_cni_version'] == $cni_version {
    tidy { 'clean old CNI plugins':
      path    => '/opt/cni/bin',
      rmdirs  => true,
      recurse => true,
      age     => '0m',
      require => File['/opt/cni/bin'],
      before  => Archive["/tmp/cni-plugins-linux-amd64-v${cni_version}.tgz"];
    }
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
    notify        => Exec["${module_name} reload nomad service"],
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
      service_content => epp("${module_name}/cni-up.service.epp", { ingress => undef }),
      timer_content   => epp("${module_name}/cni-up.timer.epp",
        {
          keep_vxlan_up_timer_interval => $keep_vxlan_up_timer_interval,
          keep_vxlan_up_timer_unit     => $keep_vxlan_up_timer_unit,
        }
      );
  }

  service {
    default:
      ensure => running,
      enable => true;
    'cni-purge.timer':
      subscribe => Systemd::Timer['cni-purge.timer'];
    'cni-up.timer':
      subscribe => Systemd::Timer['cni-up.timer'];
  }
}
# vim: set ts=2 sw=2 et :
