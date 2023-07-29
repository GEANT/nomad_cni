require 'ipaddr'
# == Function: nomad_cni::host_network_v4
#
# create host_network_v4 (array of hashes) for Nomad agent configuration
#
# parse $facts['nomad_cni_hash'], add public network and return an array of hashes for host_network_v4
#
# === Example
#
# nomad_cni::host_network_v4('eth0')
#
# === Parameters
#
# [*iface*] String
#   network interface on the Nomad agents
#
# [*ip*] Stdlib::IP::Address::V4::Nosubnet
#   IP address of the Nomad agent
#
# [*ip_type*] Optional[String]
#   IP type to use. It can be 'v4' or 'v6' or 'any. If undef, it defaults to 'v4'
#
# [*netmask*] Stdlib::IP::Address::V4::Nosubnet
#   netmask address of the Nomad agent. This is not the CIDR notation, but the netmask. For instance: 255.255.255.0
#
# [*nomad_cni_hash*] Hash
#   Hash containing the CNI configuration. It is the output of $facts['nomad_cni_hash']
#
# === Returns (example)
#
#  [
#    {
#      'public' => {
#        'cidr' => '192.168.1.1/24',
#        'interface' => 'eth0'
#      }
#    }, {
#      'test_cni_1' => {
#        'cidr' => '192.168.2.1/24',
#        'interface' => 'vxbr8365519'
#      }
#    }, {
#      'test_cni_2' => {
#        'cidr' => '192.168.3.1/24',
#        'interface' => 'vxbr5199537'
#      }
#    }
#  ]
#
Puppet::Functions.create_function(:'nomad_cni::host_network_v4') do
  dispatch :calculate_host_network_v4 do
    param 'String', :iface
    optional_param 'Variant[String, Undef]', :ip_type
    return_type 'Variant[Array[0, 0], Array[Hash]]'
  end

  def calculate_host_network_v4(iface, ip_type = 'v4')
    if ip_type == 'v4'
      ip = call_function('fact', "networking.interfaces.#{iface}.ip")
      netmask = call_function('fact', "networking.interfaces.#{iface}.netmask")
      cidr = IPAddr.new(netmask).to_i.to_s(2).count('1')
      network_addr = IPAddr.new(ip).mask(netmask).to_s + "/#{cidr}"
      public_network = [{ 'public_v4' => { 'cidr' => network_addr, 'interface' => iface } }]
    elsif ip_type == 'v6'
      ip = call_function('fact', "networking.interfaces.#{iface}.ip6")
      netmask = call_function('fact', "networking.interfaces.#{iface}.netmask6")
      cidr = IPAddr.new(netmask).to_i.to_s(2).count('1')
      network_addr = IPAddr.new(ip).mask(netmask).to_s + "/#{cidr}"
      public_network = [{ 'public_v6' => { 'cidr' => network_addr, 'interface' => iface } }]
    elsif ip_type == 'any'
      ip = call_function('fact', "networking.interfaces.#{iface}.ip")
      netmask = call_function('fact', "networking.interfaces.#{iface}.netmask")
      cidr = IPAddr.new(netmask).to_i.to_s(2).count('1')
      ip_six = call_function('fact', "networking.interfaces.#{iface}.ip6")
      netmask_six = call_function('fact', "networking.interfaces.#{iface}.netmask6")
      cidr_six = IPAddr.new(netmask_six).to_i.to_s(2).count('1')
      network_addr = IPAddr.new(ip).mask(netmask).to_s + "/#{cidr}"
      network_addr_six = IPAddr.new(ip_six).mask(netmask_six).to_s + "/#{cidr_six}"
      public_network = [
        { 'public_v4' => { 'cidr' => network_addr_six, 'interface' => iface } },
        { 'public_v6' => { 'cidr' => network_addr_six, 'interface' => iface } },
      ]
    else
      raise ArgumentError, "Invalid IP type: #{ip_type}. It must be 'v4' or 'v6' 'any' or undef. if undef, it defaults to 'v4'"
    end
    cni_hash = call_function('fact', 'nomad_cni_hash')

    if cni_hash.empty?
      cni_host_network = []
    else
      cni_names = cni_hash.keys
      cni_host_network = cni_names.map do |cni|
        ip_addr, subnet_addr = cni_hash[cni]['network'].split('/')
        network_addr = IPAddr.new(ip_addr).mask(subnet_addr).to_s + "/#{subnet_addr}"
        {
          cni => { 'cidr' => network_addr, 'interface' => "vxbr#{cni_hash[cni]['id']}" }
        }
      end
    end
    cni_host_network + public_network
  end
end
