# frozen_string_literal: true

require 'spec_helper'

describe 'nomad_cni::int_to_v4' do
  it {
    # Could not run puppet function. It is not available in the spec tests.
    # The number below is the output of: seeded_rand(268_435_455, '192.168.3.0/24') + 1)
    is_expected.to run.with_params(223_303_344 + 1).and_return('237.79.86.177')
  }
end
