# == Class: nomad_cni
#
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
# WARNING: This will overwrite any existing rc.local file
#
# [*keep_vxlan_up_cron_ensure*] Boolean
# install cron job to keep VXLANs up
#
# [*keep_vxlan_up_cron_interval*] Integer[1, 59]
# interval in minutes to run cron job to keep VXLANs up
#
class nomad_cni (
  String $cni_version = '1.2.0',
  Varian[Stdlib::HTTPSUrl, Stdlib::HTTPSUrl] $cni_base_url = 'https://github.com/containernetworking/plugins/releases/download',
  Boolean $keep_vxlan_up_cron_ensure = true,
  Integer[1, 59] $keep_vxlan_up_cron_interval = 10
) {
  class { 'nomad_cni::config':
    cni_version                 => $cni_version,
    cni_base_url                => $cni_base_url,
    keep_vxlan_up_cron_ensure   => $keep_vxlan_up_cron_ensure,
    keep_vxlan_up_cron_interval => $keep_vxlan_up_cron_interval,
  }
}
