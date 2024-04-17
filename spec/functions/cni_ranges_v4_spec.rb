# frozen_string_literal: true

require 'spec_helper'

describe 'nomad_cni::cni_ranges_v4' do
  it {
    is_expected.to run.with_params('192.168.3.0/24', ['nomad01.example.org', 'nomad02.example.org', 'nomad03.example.org'], 10).and_return(
      [
        ['nomad01.example.org', '192.168.3.2', '192.168.3.3', '192.168.3.26', 24],
        ['nomad02.example.org', '192.168.3.27', '192.168.3.28', '192.168.3.51', 24],
        ['nomad03.example.org', '192.168.3.52', '192.168.3.53', '192.168.3.76', 24],
      ],
    )
    is_expected.to run.with_params('192.168.3.0/24', ['nomad01.example.org', 'nomad02.example.org', 'nomad03.example.org'], nil).and_return(
      [
        ['nomad01.example.org', '192.168.3.2', '192.168.3.3', '192.168.3.85', 24],
        ['nomad02.example.org', '192.168.3.86', '192.168.3.87', '192.168.3.169', 24],
        ['nomad03.example.org', '192.168.3.170', '192.168.3.171', '192.168.3.253', 24],
      ],
    )
    is_expected.to run.with_params('192.168.3.0/24', ['nomad01.example.org', 'nomad02.example.org', 'nomad03.example.org'], 2).and_raise_error(
      ArgumentError,
      %r{Invalid number of networks: 2. It must be Undef or greater than the number of agents: 3},
    )
  }
end
