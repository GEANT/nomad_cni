# Nomad CNI

## Table of Contents

1. [Overview](#overview)
2. [What This Module Affects](#what-this-module-affects)
3. [Usage and examples](#usage-and-examples)
    1. [Install the CNI components](#install-the-cni-components)
    2. [Create a bunch of CNI networks](#create-a-bunch-of-cni-networks)
4. [Limitations](#limitations)

## Overview

This module configures a CNI network and it aims to replace a more complex software-defined network solution (like as Calico, Weave, Cilium...).\
Whilst Calico uses `etcd` and `nerdctl` to leverage and centralize the configuration of the cluster, this module splits a network range by the number of Nomad agents, and it creates a number of configuration files for every agent. Each configuration will have a different gateway and will use a different IP range within the same subnet.\
The module will also create a Bridge interface on each Agent and the bridge will be attached to a VXLAN. All the names of the interface are randomized.

## What This Module Affects <a name="what-this-module-affects"></a>

* Installs the CNI network plugins (via url)
* Installs a configuration file for each CNI network (/etc/cni/vxlan.d/*.conf)
* Creates a Bridge and a VXLAN for each CNI network (managed via custom script)

## Usage and examples <a name="usage-and-examples"></a>

### Install the CNI components

basic installation

```puppet
include nomad_cni
```

or if you want to manage yourself the script at boot time

```puppet
class { 'nomad_cni':
  manage_rc_local => false,
}
```

### Create a bunch of CNI networks

```puppet
nomad_cni::cni_v4 {
  'cni1':
    network => '192.168.1.0/24';
  'swd1':
    network => '192.168.2.0/24';
  'swd2':
    network => '192.168.3.0/24';
  'swd3':
    network => '192.168.4.0/24';
}
```

## Limitations

* the function `cni_ranges` currently supports only networks equal or less than 24 bits (if you love Ruby please help improving the algorithm)
* only macvlan plugin is supported
