# frozen_string_literal: true

require 'facter'

# This facter checks if CNI is installed and returns the version number or '0'
#
Facter.add(:nomad_cni_version) do
  confine kernel: 'Linux'
  setcode do
    Facter::Util::Resolution.exec('/opt/cni/bin/bridge 2>&1').split("\n").first.split.last.gsub(%r{^v}, '')
  rescue
    'unknown'
  end
end
