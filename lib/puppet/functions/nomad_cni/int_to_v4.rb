require 'ipaddr'
# Function to split a network by a given number of hosts (Nomad agents)
#
# network_address: String in CIDR notation (e.g. "192.168.0.0/24")
#
# agent_names: Array of strings containing the names of the Nomad agents
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
Puppet::Functions.create_function(:'nomad_cni::int_to_v4') do
  dispatch :int_to_v4 do
    param 'Integer[0,268435455]', :multicast_int_addr
    return_type 'Stdlib::IP::Address::V4::Nosubnet'
  end

  def int_to_v4(multicast_int_addr)
    real_int_address = multicast_int_addr + 4026531840
    IPAddr.new(real_int_address, Socket::AF_INET).to_s
    end
  end
end
