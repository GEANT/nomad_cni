# Nomad CNI

## Table of Contents

1. [Overview](#overview)
2. [Requirements and notes](#requirements-and-notes)
3. [What this module affects](#what-this-module-affects)
4. [Usage and examples](#usage-and-examples)
    1. [Install the CNI components](#install-the-cni-components)
    2. [Create a bunch of CNI networks](#create-a-bunch-of-cni-networks)
5. [CNIs segregation and interconnection](#cnis-segregation-and-interconnection)
7. [Limitations](#limitations)

## Overview

This module configures CNI networks on the Nomad agents, and it aims to replace a more complex software-defined network solution (like as Calico, Weave, Cilium...).\
Whilst Calico uses `etcd` and `nerdctl` to leverage and centralize the configuration of the CNI within the cluster, this module splits a network range by the number of Nomad agents, and assigns each range to a different agent.\
The module will also create a Bridge interface and a VXLAN on each Agent and the VXLANs will be interconnected and bridged with the host network.

## Requirements and notes

In addition to the requirements listed in `metadata.json`, **this module requires PuppetDB**.\
The CNI configuration has a stanza for the DNS settings, but these settings don't work, because Nomad has its own settings for the DNS in the job configuration, and by default Nomad copies over the content of `resolv.conf` from the host onto the container.

## What this module affects <a name="what-this-module-affects"></a>

* Installs the CNI network plugins (via url)
* Installs a configuration file for every CNI network (`/etc/cni/vxlan.d/vxlan*.conf`)
* Creates a Bridge and a VXLAN for every CNI network (managed via custom script)

## Usage and examples <a name="usage-and-examples"></a>

### Install the CNI components

basic usage

```puppet
include nomad_cni
```

if you want to change the download URL and you want to specify the version to install:

```puppet
class { 'nomad_cni':
  cni_version  => '1.5.0',
  cni_base_url => https://server.example.org/cni/,
}
```

### Create a bunch of CNI networks

`agent_regex` will only match nodes within the same Puppet environment (i.e. on test you won't be able to match a node from the production environment). Alternatively you can use `agent_list`.\
Using following you can setup to CNI networks, using the unicast vxlan technology:

```puppet
nomad_cni::macvlan::unicast::v4 {
  default:
    agent_regex => 'nomad0';
  'cni1':
    network => '192.168.1.0/24';
  'cni2':
    network => '172.16.2.0/22';
}
```

Multicast shuold be better, but in my environment it wasn't reliable. Feel free to experiment at your own risk.

## CNIs segregation and interconnection

By default all CNIs can connect to each other.\
CNIs segregation is achieved with `iptables` (the module `firewall_multi` is used), and it's enabled by setting `cni_cut_off` to `true`:

```puppet
class { 'nomad_cni':
  cni_cut_off  => true
}
```

Once you have cut off the CNIs, you can interconnect some of them using the following resource:

```puppet
nomad_cni::cni_connect {['test-cni-1', 'test-cni-2']: }
```

If you need encryption, or you need to interconnect only certain services, you can either:

1. help implementing `wireguard` in this module (to enable encryption)
2. use [Consul Connect](https://www.hashicorp.com/products/consul) (to enable encryption and interconnectio single service)

## Limitations

* currently only IPv4 is supported
* currently only `macvlan` plugin is supported (any reason to use a different plugin?)
* vlxlan are brought up with systemd, but a link failure is not detected by systemd service (there is a cron job to ensure that the network is up)
* unit test is always on my mind, but it's not yet ready
