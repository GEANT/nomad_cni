# frozen_string_literal: true

require 'facter'

# This facter checks if we are migrating from 0.9.1 to a higher version
#
#
Facter.add(:is_nomad_cni_agent) do
  confine kernel: 'Linux'
  setcode do
    if Facter::Util::Resolution.which('nomad')
      'true'
    else
      false
    end
  end
end
