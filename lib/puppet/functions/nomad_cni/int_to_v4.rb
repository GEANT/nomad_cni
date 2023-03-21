require 'ipaddr'
# Function to split a network by a given number of hosts (Nomad agents)
#
# multicast_int_addr: IP address converted to decimal integer
#
# Returns: Multicast IP address in octet format
#
# Example: nomad_cni::int_to_v4(seeded_rand(268435455, $network))
#          we don't know seeded_rand output, but it may return: 237.79.86.177
#
Puppet::Functions.create_function(:'nomad_cni::int_to_v4') do
  dispatch :int_to_v4 do
    param 'Integer[0,268435455]', :multicast_int_addr
    return_type 'Stdlib::IP::Address::V4::Nosubnet'
  end

  def int_to_v4(multicast_int_addr)
    real_int_address = multicast_int_addr + 3_758_096_384
    IPAddr.new(real_int_address, Socket::AF_INET).to_s
  end
end
