# frozen_string_literal: true

require 'spec_helper'

describe 'nomad_cni::host_network_v4' do
  it {
    is_expected.to run.with_params('eth0').and_return(
      [
        { 'test_cni_1' => { 'cidr' => '192.168.2.1/24', 'interface' => 'vxbr11882895' } },
        { 'test_cni_2' => { 'cidr' => '192.168.3.1/24', 'interface' => 'vxbr5199537' } },
        { 'test_cni_3' => { 'cidr' => '192.168.4.1/24', 'interface' => 'vxbr15782095' } },
        { 'public_v4' => { 'cidr' => '172.16.254.254/16', 'interface' => 'eth0' } },
      ],
    )
  }
end
