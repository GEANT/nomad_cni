Facter.add('nomad_cni_hash') do
  # create a hash containing the name of the CNI and Vxlan ID
  #
  # Example: {"cni" => "123456", "cni2" => "78901234"}
  #
  setcode do
    cni_hash_output = {}
    cni_scripts = Dir.glob('/etc/vxlan/*cast.d/*.sh')
    cni_scripts.each do |cni_script|
      cni_name = File.basename(cni_script, '.sh')
      vxlan_network = File.read(cni_script).match(%r{^vxlan_network="(.*)"})[1]
      vxlan_id = File.read(cni_script).match(%r{^vxlan_id=(\d+)})[1]
      cni_hash_output[cni_name] = vxlan_id
    end
    cni_hash_output
  rescue
    {}
  end
end
