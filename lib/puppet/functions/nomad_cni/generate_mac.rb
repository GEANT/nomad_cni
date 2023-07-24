require 'digest'

# Function to generated a  decimal to IP address
#
#
# Returns: Mac Address
#
# Example: nomad_cni::generate_mac('some_string')
#      returns 02:31:ee:76:26:1d:87"
#
Puppet::Functions.create_function(:'nomad_cni::generate_mac') do
  dispatch :generate_mac do
    param 'String', :input_string
    return_type 'String'
  end
  def generate_mac(input_string)
    # Hash the IP address to generate a unique value
    hashed_value = Digest::MD5.hexdigest(input_string)

    # Take the first 6 bytes of the hash to form the MAC address
    mac_address = hashed_value[0..11]

    # Format the MAC address with colons
    final_mac_address = mac_address.scan(%r{.{2}}).join(':')

    final_mac_address
  end
end
