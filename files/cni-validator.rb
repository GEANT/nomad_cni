#!/opt/puppetlabs/puppet/bin/ruby
#
# ensure that the network is unique
#
require 'json'
require 'docopt'

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
occurrences_count = 0
files_array = [tmp_file]
files_array.push(conf_file) if File.file?(conf_file)

Dir.glob('/opt/cni/config/*').each do |f|
  next if files_array.include?(f)
  next unless File.readlines(f).any? { |line| line.include?(cidr) }
  occurrences_count += 1
  puts "Network #{cidr} already exists in #{f}"
end

exit 1 if occurrences_count > 0
