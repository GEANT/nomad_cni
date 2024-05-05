type Nomad_cni::Vip::Cidr = Variant[
  Stdlib::IP::Address::V4::CIDR,
  Array[Variant[Stdlib::IP::Address::V4::CIDR, Stdlib::IP::Address::V6::CIDR], 2]
]
