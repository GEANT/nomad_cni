#!/opt/puppetlabs/puppet/bin/ruby
#
# ensure that the network is unique
#
require 'json'
require 'docopt'
require 'ipaddr'

doc = <<DOCOPT
CNI Duplicates checker.

Usage:
  #{__FILE__} --tmp-file <TMPFILE> --conf-file <CONFFILE> --cidr <CIDR>
  #{__FILE__} -h | --help

Options:
  -h --help               Show this screen.
  --cidr=<cidr>           CIDR to check.
  --tmp-file=<TMPFILE>    Puppet temporary file.
  --conf-file=<CONFFILE>  The file resource that we are validating.

DOCOPT

begin
  args = Docopt.docopt(doc)
rescue Docopt::Exit => e
  puts e.message
end

cidr = args['--cidr']
conf_file = args['--conf-file']
tmp_file = args['--tmp-file']
overlaps_count = 0
files_array = [tmp_file]
files_array.push(conf_file) if File.file?(conf_file)

def networks_overlap?(network1, network2)
  ip1 = IPAddr.new(network1)
  ip2 = IPAddr.new(network2)

  # Check if the network addresses are the same
  return true if ip1.to_s == ip2.to_s

  # Check if the networks overlap
  ip1.include?(ip2) || ip2.include?(ip1)
end

# Check if the network overlaps with any other network in the CNI config files
Dir.glob('/opt/cni/config/*').each do |f|
  subnet = JSON.parse(test)['plugins'][1]['ipam']['ranges'][0][0]['subnet']
  next unless networks_overlap?(cidr, subnet)
  overlaps_count += 1
  puts "Network #{cidr} overlaps with #{subnet} in #{f}"
end

exit 1 if occurrences_count > 0 || overlaps_count > 0

# vim: ft=ruby
