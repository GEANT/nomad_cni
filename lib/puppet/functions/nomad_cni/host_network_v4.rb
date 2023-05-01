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

  def calculate_host_network_v4(iface)
    ip = call_function('fact', "networking.interfaces.#{iface}.ip")
    netmask = call_function('fact', "networking.interfaces.#{iface}.netmask")
    cni_hash = call_function('fact', 'nomad_cni_hash')
    cidr = IPAddr.new(netmask).to_i.to_s(2).count('1')
    public_network = [{ 'public_v4' => { 'cidr' => "#{ip}/#{cidr}", 'interface' => iface } }]

    if cni_hash.empty?
      cni_host_network = []
    else
      cni_names = cni_hash.keys
      cni_host_network = cni_names.map do |cni|
        {
          cni => { 'cidr' => cni_hash[cni]['network'], 'interface' => "vxbr#{cni_hash[cni]['id']}" }
        }
      end
    end
    cni_host_network + public_network
  end
end
