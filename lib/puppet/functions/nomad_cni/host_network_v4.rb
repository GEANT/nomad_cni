require 'facter'
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
    return_type 'Variant[Array[0, 0], Array[Hash]]'
  end

  def networks_overlap?(network1, network2)
    ip1 = IPAddr.new(network1)
    ip2 = IPAddr.new(network2)

    # Check if the network addresses are the same
    return true if ip1.to_s == ip2.to_s

    # Check if the networks overlap
    ip1.include?(ip2) || ip2.include?(ip1)
  end

  def overlapping_networks?(networks)
    # Iterate over each network and compare it to every other network
    (0...networks.length).each do |i|
      (i + 1...networks.length).each do |j|
        if networks_overlap?(networks[i], networks[j])
          return [networks[i], networks[j]]
        end
      end
    end

    # If no overlapping networks are found, return nil
    nil
  end

  def calculate_host_network_v4(iface)
    ip = call_function('fact', "networking.interfaces.#{iface}.ip")
    netmask = call_function('fact', "networking.interfaces.#{iface}.netmask")
    cni_hash = call_function('fact', 'nomad_cni_hash')
    cidr = IPAddr.new(netmask).to_i.to_s(2).count('1')
    public_network = [{ 'public' => { 'cidr' => "#{ip}/#{cidr}", 'interface' => iface } }]

    if cni_hash.empty?
      cni_host_network = []
    else
      cni_names = cni_hash.keys
      cni_networks = cni_names.map { |cni| cni_hash[cni]['network'] }
      overlaps = overlapping_networks?(cni_networks)
      if overlaps
        raise Puppet::ParseError, "CNI networks #{overlaps.join(' and ')} overlap"
      end
      cni_host_network = cni_names.map do |cni|
        {
          cni => { 'cidr' => cni_hash[cni]['network'], 'interface' => "vxbr#{cni_hash[cni]['network']}" }
        }
      end
    end
    cni_host_network + public_network
  end
end
