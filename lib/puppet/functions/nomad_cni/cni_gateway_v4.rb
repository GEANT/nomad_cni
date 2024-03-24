require 'ipaddr'
# Function to return the first IP of a network to be used as the gateway
#
# network_address: String in CIDR notation (e.g. "192.168.0.0/24")
#
# Returns: Gateway IP address for the CNI (namely the first IP of the netowrk):
#
# Example: nomad_cni::cni_gateway("192.168.0.0/24")
#          returns "192.168.0.1"
#
Puppet::Functions.create_function(:'nomad_cni::cni_gateway_v4') do
  dispatch :calculate_cni_gateway_v4 do
    param 'Stdlib::IP::Address::V4::CIDR', :network_address
    return_type 'Stdlib::IP::Address::V4::Nosubnet'
  end

  def calculate_cni_gateway_v4(network_address)
    IPAddr.new(network_address).to_range.first.to_s
  end
end
