# Nomad CNI

## Table of Contents

1. [Overview](#overview)
2. [What This Module Affects](#what-this-module-affects)
3. [Usage and examples](#usage-and-examples)
    1. [Install the CNI components](#install-the-cni-components)
    2. [Create a bunch of CNI networks](#create-a-bunch-of-cni-networks)
4. [Limitations](#limitations)

## Overview

This module configures a CNI network on the Nomad agents, and it aims to replace a more complex software-defined network solution (like as Calico, Weave, Cilium...).\
Whilst Calico uses `etcd` and `nerdctl` to leverage and centralize the configuration of the cluster, this module splits a network range by the number of Nomad agents, and it creates a number of configuration files for every agent. Each configuration will have a different gateway and will use a different IP range within the same subnet.\
The module will also create a Bridge interface and a VXLAN on each Agent and the VXLAN will be bridged onto the CNI.

## What This Module Affects <a name="what-this-module-affects"></a>

* Installs the CNI network plugins (via url)
* Installs a configuration file for every CNI network (`/etc/cni/vxlan.d/*.conf`)
* Creates a Bridge and a VXLAN for every CNI network (managed via custom script)

## Usage and examples <a name="usage-and-examples"></a>

### Install the CNI components

basic usage

```puppet
include nomad_cni
```

if you don't want this module to manage the script at boot time

```puppet
class { 'nomad_cni':
  manage_startup_script => false,
}
```

### Create a bunch of CNI networks

```puppet
nomad_cni::macvlan_v4 {
  default:
    agent_regex => 'nomad0',
    dns_servers => ['8.8.8.8', '8.8.4.4'];
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

* the function `cni_ranges` currently only supports networks greater than or equal to 24 bits (i.e.: it works with a maximum of 254 hosts). If you love Ruby, please help improving the algorithm of the function
* only `macvlan` plugin is supported at the moment
