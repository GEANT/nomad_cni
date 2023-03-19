require 'ipaddr'
# Function to split a network by a given number of hosts (Nomad agents)
#
# network_address: String in CIDR notation (e.g. "192.168.0.0/24")
#
# agent_names: Array of strings containing the names of the Nomad agents
#
# Returns: Array of arrays, and each array contains:
#        - the name of the agent
#        - the gateway of the VXLAN on the host that will be used for the VXLAN on the host
#        - the first usable number for the range in the CNI config
#        - the last usable number for the range in the CNI config
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
    return_type 'Array[Array]'
  end

  def calculate_cni_ranges_v4(network_address, agent_names)
    sorted_agent_names = agent_names.sort
    netmask = network_address.split('/')[1].to_i
    last_ip_integer = IPAddr.new(network_address).to_range.last.to_i
    first_ip_integer = IPAddr.new(network_address).to_range.first.to_i
    free_hosts = last_ip_integer - first_ip_integer - 1

    agent_number = agent_names.length
    chunk_size = (free_hosts / agent_number).floor
    agents_array = (0..agent_number - 1).to_a
    agents_array.map do |item|
      [
        sorted_agent_names[item], # agent name
        IPAddr.new((first_ip_integer + (chunk_size * item) + 1).to_i, Socket::AF_INET).to_s,  # gateway, and VXLAN IP on the host
        IPAddr.new((first_ip_integer + (chunk_size * item) + 2).to_i, Socket::AF_INET).to_s,  # first usable IP in the range
        IPAddr.new((first_ip_integer + (chunk_size * item) + chunk_size).to_i, Socket::AF_INET).to_s, # last usable IP in the range
        netmask,  # netmask
      ]
    end
  end
end
