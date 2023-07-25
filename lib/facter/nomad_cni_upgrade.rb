# frozen_string_literal: true

require 'facter'

# This facter checks if we are migrating from 0.9.1 to a higher version
#
#
Facter.add(:nomad_cni_upgrade) do
  confine kernel: 'Linux'
  setcode do
    Facter::Util::Resolution.exec('grep -qw macvlan /opt/cni/config/*.conflist && echo true')
  rescue
    nil
  end
end
