# frozen_string_literal: true

require 'spec_helper'

describe 'nomad_cni::host_network_v4' do
  it {
    is_expected.to run.with_params(
      '129.168.1.10', '255.255.255.0',
      {
        'cni1' => { 'id' => '1233456', 'network' => '192.168.20.0/24' },
        'cni2' => { 'id' => '5678901', 'network' => '192.168.10.0/24' },
      }, 'eth0'
    ).and_return(
      [
        { 'cni1'  => { 'cidr' => '129.168.1.10/24', 'interface' => 'eth0' } },
        { 'cni2'  => { 'cidr' => '129.168.1.10/24', 'interface' => 'eth0' } },
        { 'public' => { 'cidr' => '129.168.1.10/24', 'interface' => 'eth0' } },
      ],
    )
  }
end
