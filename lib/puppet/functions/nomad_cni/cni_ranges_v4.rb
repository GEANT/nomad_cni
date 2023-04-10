require 'ipaddr'
# Function to split a network by a given number of hosts (Nomad agents)
#
# network_address: String in CIDR notation (e.g. "192.168.0.0/24")
#
# agent_names: Array of strings containing the names of the Nomad agents
#
# min_networks: Optional integer, allows to overcommit the number of network.
#               It can be undef of greater than number of agents. Unused networks
#               won't be assigned to any agent (and won't be returned by the function)
#
# Returns: Array of arrays, and each array contains:
#        - the name of the agent
#        - the gateway for the CNI that will be assigned to the VXLAN on the host
#        - the first usable IP for the range in the CNI config
#        - the last usable IP for the range in the CNI config
#        - the netmask
#
# Example: nomad_cni::cni_ranges_v4("192.168.0.0/24", ["agent1.foo.org", "agent2.foo.org", "agent3.foo.org"]])
#          returns [
#                    ["agent1.foo.org", 192.168.0.1, 192.168.0.2, 192.168.0.84, 24],
#                    ["agent2.foo.org", 192.168.0.85, 192.168.0.86, 192.168.0.168, 24],
#                    ["agent3.foo.org", 192.168.0.169, 192.168.0.170, 192.168.0.252, 24]
#                  ]
#
Puppet::Functions.create_function(:'nomad_cni::cni_ranges_v4') do
  dispatch :calculate_cni_ranges_v4 do
    param 'Stdlib::IP::Address::V4::CIDR', :network_address
    param 'Array[String]', :agent_names
    param 'Optional[Integer]', :min_networks
    return_type 'Array[Array]'
  end

  def calculate_cni_ranges_v4(network_address, agent_names, min_networks)
    netmask = network_address.split('/')[1].to_i
    address = network_address.split('/')[0].to_s
    first_ip = IPAddr.new(network_address).to_range.first.to_s

    if first_ip != address
      raise ArgumentError, "Invalid network address: #{network_address}. The correct address for this network is: #{first_ip}/#{netmask}"
    end

    sorted_agent_names = agent_names.sort
    last_ip_int = IPAddr.new(network_address).to_range.last.to_i
    first_ip_int = IPAddr.new(network_address).to_range.first.to_i
    free_hosts = last_ip_int - first_ip_int - 1
    agent_number = agent_names.length

    if !min_networks.nil?
      raise ArgumentError, "Invalid number of networks: #{min_networks}. It must be Undef or greater than the number of agents: #{agent_number}" if min_networks < agent_number
      number_of_networks = min_networks
    else
      number_of_networks = agent_number
    end

    chunk_size = (free_hosts / number_of_networks).floor
    agents_array = (0..agent_number - 1).to_a
    agents_array.map do |item|
      [
        sorted_agent_names[item], # agent name
        IPAddr.new((first_ip_int + (chunk_size * item) + 1).to_i, Socket::AF_INET).to_s, # gateway, and VXLAN IP on the host
        IPAddr.new((first_ip_int + (chunk_size * item) + 2).to_i, Socket::AF_INET).to_s, # first usable IP in the range
        IPAddr.new((first_ip_int + (chunk_size * item) + chunk_size).to_i, Socket::AF_INET).to_s, # last usable IP in the range
        netmask, # netmask
      ]
    end
  end
end
