# frozen_string_literal: true

require 'spec_helper'
describe 'nomad_cni::int_to_v4' do
  let(:pre_condition) do
    'include stdlib'
  end

  it {
    # is_expected.to run.with_params(seeded_rand(268_435_455, '192.168.3.0/24') + 1).and_return('237.79.86.177')
    is_expected.to run.with_params(223_303_344 + 1).and_return('237.79.86.177')
  }
end
