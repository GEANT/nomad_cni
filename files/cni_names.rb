#!/usr/bin/env ruby
require 'yaml'

cni_conf = Dir.glob('/opt/cni/config/*.conflist')
cni_names = cni_conf.map { |f| File.basename(f, '.conflist') }

puts({ 'cni_names' => cni_names }.to_yaml)
