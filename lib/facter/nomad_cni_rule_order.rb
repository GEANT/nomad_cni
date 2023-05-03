# frozen_string_literal: true

require 'facter'

# This facter returns the rule ordfer for the CNI chain
#
Facter.add(:nomad_cni_hash) do
  confine kernel: 'Linux'
  setcode do
    Facter::Util::Resolution.exec('iptables-save | awk /"CNI-ISOLATION-INPUT chain"/').split('"')[1].split.first
  rescue
    nil
  end
end
