Facter.add('nomad_cni_hash') do
  # create a hash containing the name of the CNI and the subkeys Vxlan ID and network
  #
  # Example: {
  #   'cni1' => { 'id' => '1233456', 'network' => '192.168.20.0/24' },
  #   'cni2' => { 'id' => '5678901', 'network' => '192.168.10.0/24' }
  # }
  #
  setcode do
    cni_hash = {}
    cni_scripts = Dir.glob('/opt/cni/vxlan/*cast.d/*.sh')
    cni_scripts.each do |cni_script|
      cni_name = File.basename(cni_script, '.sh')
      vxlan_network = File.read(cni_script).match(%r{^vxlan_network="(.*)"})[1]
      vxlan_id = File.read(cni_script).match(%r{^vxlan_id=(\d+)})[1]
      cni_hash.merge!({
                        cni_name => {
                          'id' => vxlan_id,
                         'network' => vxlan_network
                        }
                      })
    end
    cni_hash
  rescue
    {}
  end
end
