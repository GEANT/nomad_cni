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
  $directory_list = ['/opt/cni', '/opt/cni/bin', '/opt/vxlan', '/run/cni', '/etc/cni', '/etc/cni/vlxlan.d']

  file {
    default:
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0755';
    $directory_list:
      ensure => directory;
    '/opt/cni/config':
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true;
    '/usr/local/bin/cni-validator.sh':
      source => "puppet:///modules/${module_name}/cni-validator.sh";
    '/usr/local/bin/vxlan-configurator.sh':
      source => "puppet:///modules/${module_name}/vxlan-configurator.sh";
  }

  # install python3-demjson and fping
  #
  $packages = ['python3-demjson', 'fping']
  $packages.each |String $package| {
    unless defined(Package[$package]) {
      package { $package: ensure => present, }
    }
  }

  exec { 'remove_old_cni':
    command => 'rm -f /opt/cni/bin/*',
    unless  => "test -f /opt/cni/bin/bridge && /opt/cni/bin/bridge 2>&1 | awk -F' v' '/plugin/{print \$NF}' | grep -w \"${cni_version}\"",
    path    => '/usr/bin';
  }

  -> archive { "/tmp/cni-plugins-linux-amd64-v${cni_version}.tgz":
    ensure        => present,
    cleanup       => true,
    extract       => true,
    extract_path  => '/opt/cni/bin',
    source        => "${cni_base_url}/v${cni_version}/cni-plugins-linux-amd64-v${cni_version}.tgz",
    creates       => '/opt/cni/bin/bridge',
    checksum_url  => "${cni_base_url}/v${cni_version}/cni-plugins-linux-amd64-v${cni_version}.tgz.sha256",
    checksum_type => 'sha256',
    require       => File['/opt/cni/bin'];
  }

  # create startup script
  #
  if ($manage_startup_script) {
    file {
      '/etc/rc.local':
        ensure => link,
        target => 'rc.d/rc.local';
      '/etc/rc.d/rc.local':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => "puppet:///modules/${module_name}/rc.local";
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
  cron { 'keep-vxlan-up':
    ensure  => $keep_vxlan_up_cron_ensure,
    command => '/usr/local/bin/vxlan-configurator.sh --all',
    user    => 'root',
    hour    => '*',
    minute  => "*/${$keep_vxlan_up_cron_interval}",
  }
}
