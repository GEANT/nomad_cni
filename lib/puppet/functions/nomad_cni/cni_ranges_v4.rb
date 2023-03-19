# Function to split a network by a given number of hosts (Nomad agents)
#
# network_address: String in CIDR notation (e.g. "192.168.0.0/24")
#
# agent_names: Array of strings containing the names of the Nomad agents
#
# Returns: Array of arrays, and each array contains the IP of the VXLAN on the
#          host, the start number for the range and the end number for the range
#
# Example usage: nomad_cni::cni_ranges_v4("192.168.0.0/24", ["agent1.example.org", "agent2.example.org", "agent3.example.org"]])
#                returns [[1, 2, 84], [85, 86, 168], [169, 170, 252]]
#
Puppet::Functions.create_function(:'nomad_cni::cni_ranges_v4') do
  dispatch :calculate_cni_ranges_v4 do
    param 'Stdlib::IP::Address::V4::CIDR', :network_address
    param 'Array[String]', :agent_names
    return_type 'Array[Array]'
  end

  def calculate_cni_ranges_v4(network_address, agent_names)
    netmask = network_address.split('/')[1].to_i
    ip = network_address.split('/')[0]
    net_prefix = ip.split('.')[0...-1].join('.')
    raise Puppet::Error, 'this function does not work with subnets greater than 24' if netmask > 24

    hosts_without_broadcast = 2**(32 - netmask) - 2 - 1
    agents = agent_names.length
    chunk_size = (hosts_without_broadcast / agents).floor
    agents_array = (0..agents - 1).to_a
    agents_array.map do |item|
      [
        agent_names[item],
        "#{net_prefix}." + (item * chunk_size + 1).to_s,
        "#{net_prefix}." + (item * chunk_size + 2).to_s,
        "#{net_prefix}." + (item * chunk_size + chunk_size).to_s,
        netmask,
      ]
    end
  end
end
