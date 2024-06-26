# frozen_string_literal: true

require 'facter'

# This facter checks if we are migrating from 0.9.1 to a higher version
#
#
Facter.add(:nomad_cni_upgrade) do
  confine kernel: 'Linux'
  setcode do
    macvlan = Facter::Util::Resolution.exec('grep -ho vxbr /opt/cni/vxlan/unicast.d/*.sh')
    if macvlan.empty?
      false
    else
      'true'
    end
  end
end
