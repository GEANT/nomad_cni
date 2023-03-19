# Nomad CNI

## Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [What this module affects](#what-this-module-affects)
4. [Usage and examples](#usage-and-examples)
    1. [Install the CNI components](#install-the-cni-components)
    2. [Create a bunch of CNI networks](#create-a-bunch-of-cni-networks)
5. [Limitations](#limitations)

## Overview

This module configures a CNI network on the Nomad agents, and it aims to replace a more complex software-defined network solution (like as Calico, Weave, Cilium...).\
Whilst Calico uses `etcd` and `nerdctl` to leverage and centralize the configuration of the CNI within the cluster, this module splits a network range by the number of Nomad agents, and it creates a number of configuration files for every agent. Each configuration will have a different gateway and will use a different IP range within the same subnet.\
The module will also create a Bridge interface and a VXLAN on each Agent and the VXLAN will be bridged between the host and the CNI.

## Requirements

Apart from the modules `puppetlabs/stdlib` and `puppet/systemd`, this module requires PuppetDB, because it uses collected resources and if you use the optional paramter `agent_regex`, it runs a query against the PuppetDB.

## What this module affects <a name="what-this-module-affects"></a>

* Installs the CNI network plugins (via url)
* Installs a configuration file for every CNI network (`/etc/cni/vxlan.d/*.conf`)
* Creates a Bridge and a VXLAN for every CNI network (managed via custom script)

## Usage and examples <a name="usage-and-examples"></a>

### Install the CNI components

basic usage

```puppet
include nomad_cni
```

if want to change the download URL and you want to specify the version to install:

```puppet
class { 'nomad_cni':
  cni_version  => '1.5.0',
  cni_base_url => https://server.example.org/cni/,
}
```

### Create a bunch of CNI networks

To make it work, puppet must run twice on all the nodes (due to the way of working of resource collection)

```puppet
nomad_cni::macvlan::v4 {
  default:
    dns_search_domains => ['example.org', 'example.net']
    dns_domain => 'geant.org'
    dns_servers => ['8.8.8.8', '8.8.4.4'],
    agent_regex => 'nomad0';
  'cni1':
    network => '192.168.1.0/24';
  'cni2':
    network => '172.16.2.0/22';
}
```

## Limitations

* currently only IPv4 is supported (`nomad_cni::macvlan::v6` is a place-holder and it does nothing)
* currently only `macvlan` plugin is supported
* `nameservers`, `domain`, and `search` do not seem to work, as `resolv.conf` is being copied from the host in the container. Perhaps these settings are not effective with Nomad
