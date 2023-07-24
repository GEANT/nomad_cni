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

    # Take the first 5 bytes of the hash to form the MAC address
    mac_address = hashed_value[0..9]

    # Format the MAC address with colons
    formatted_mac_address = mac_address.scan(%r{.{2}}).join(':')

    # Add a common MAC address prefix (Optional, but it can make it look more like a MAC address)
    final_mac_address = "02:#{formatted_mac_address}"

    final_mac_address
  end
end
