#!/opt/puppetlabs/puppet/bin/ruby
#
# ensure that the networks are not overlapping
#
require 'json'
require 'docopt'
require 'ipaddr'

doc = <<DOCOPT
CNI Duplicates checker.

Usage:
  #{__FILE__} --puppet-tmp-file <TMPFILE> --conf-file <CONFFILE> --cidr <CIDR>
  #{__FILE__} -h | --help

Options:
  -h --help                    Show this screen
  --cidr=<CIDR>                CIDR to check
  --puppet-tmp-file=<TMPFILE>  Puppet temporary file
  --conf-file=<CONFFILE>       The file resource that we are validating

DOCOPT

begin
  args = Docopt.docopt(doc)
rescue Docopt::Exit => e
  puts e.message
  exit
end

cidr = args['--cidr']
files_array = [args['--puppet-tmp-file'], args['--conf-file']]
overlaps_count = 0

def networks_overlap?(network1, network2)
  ip1 = IPAddr.new(network1)
  ip2 = IPAddr.new(network2)

  # Check if the networks overlap
  ip1.include?(ip2) || ip2.include?(ip1)
end

# Check if the network overlaps with any other network in the CNI config directory
Dir.glob('/opt/cni/config/*').each do |f|
  next if files_array.include?(f)
  file_content = File.read(f)
  subnet = JSON.parse(file_content)['plugins'][1]['ipam']['ranges'][0][0]['subnet']
  next unless networks_overlap?(cidr, subnet)
  overlaps_count += 1
  puts "Network #{cidr} overlaps with #{subnet} in #{f}"
end

exit 1 if overlaps_count > 0

# vim: ft=ruby
