# frozen_string_literal: true

require 'facter'

# This facter checks if we are migrating from 0.9.1 to a higher version
#
#
Facter.add(:nomad_cni_upgrade) do
  confine kernel: 'Linux'
  setcode do
    Facter::Util::Resolution.exec('grep -how macvlan /opt/cni/config/*.conflist')
  rescue
    nil
  end
end
