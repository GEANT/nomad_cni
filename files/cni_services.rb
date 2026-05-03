#!/usr/bin/env ruby
require 'yaml'

cni_conf = Dir.glob('/opt/cni/config/*.conflist')
cni_services = cni_conf.map { |f| 'cni-id@' + File.basename(f, '.conflist') + '.service' }

puts({ 'cni_services' => cni_services }.to_yaml)
