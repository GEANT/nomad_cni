# frozen_string_literal: true

require 'facter'

# This facter checks if Nomad is installed and return the version number or false
#
Facter.add(:is_nomad_cni_agent) do
  confine kernel: 'Linux'
  setcode do
    Facter::Util::Resolution.exec('nomad version').split("\n").first.split.last.gsub(%r{^v}, '')
  rescue
    false
  end
end
