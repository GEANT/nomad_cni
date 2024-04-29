require 'ipaddr'
# Function to return the first and the second IP of a network to be used by the Ingress server
#
# network_address: String in CIDR notation (e.g. "192.168.0.0/24")
#
# Returns: Network address and Gateway IP address for the CNI :
#
# Example: nomad_cni::cni_gateway("192.168.0.0/24")
#          returns ["192.168.0.0", "192.168.0.1"]
#
Puppet::Functions.create_function(:'nomad_cni::cni_ingress_v4') do
  dispatch :calculate_cni_ingress_v4 do
    param 'Stdlib::IP::Address::V4::CIDR', :network_address
    return_type 'Array[Stdlib::IP::Address::V4::Nosubnet]'
  end

  def calculate_cni_ingress_v4(network_address)
    first_ip = IPAddr.new(network_address).to_range.first.to_s
    second_ip_int = IPAddr.new(network_address).to_range.first.to_i + 1
    second_ip = IPAddr.new(second_ip_int, Socket::AF_INET).to_s
    [
      first_ip,
      second_ip,
    ]
  end
end
