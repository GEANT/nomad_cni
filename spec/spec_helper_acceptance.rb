# frozen_string_literal: true

RSpec.configure do |c|
  c.mock_with :rspec
end

require 'puppet_litmus'
require 'spec_helper_acceptance_local' if File.file?(File.join(File.dirname(__FILE__), 'spec_helper_acceptance_local.rb'))

PuppetLitmus.configure!
