# Nomad CNI

## Table of Contents

1. [Important notice](#important-notice)
2. [Overview](#overview)
3. [Requirements and notes](#requirements-and-notes)
4. [What this module affects](#what-this-module-affects)
5. [Usage and examples](#usage-and-examples)
    1. [Install the CNI components](#install-the-cni-components)
    2. [Create a bunch of CNI networks](#create-a-bunch-of-cni-networks)
6. [Limitations](#limitations)

## Important notice

**This modules is still experimental.** Use it and test it at your own risk.

## Overview

This module configures a CNI network on the Nomad agents, and it aims to replace a more complex software-defined network solution (like as Calico, Weave, Cilium...).\
Whilst Calico uses `etcd` and `nerdctl` to leverage and centralize the configuration of the CNI within the cluster, this module splits a network range by the number of Nomad agents, and assigns each range to a different agent.\
The module will also create a Bridge interface and a VXLAN on each Agent and the VXLANs will be interconnected and bridged with the host network.

## Requirements and notes

In addition to the requirements listed in `metadata.json`, **this module requires PuppetDB** (configured to access exported resources).\
The CNI configuration has a stanza for the DNS settings, but these settings are not effective as Nomad has its own setting for the DNS in the job configuration, or by default it copies over the content of `resolv.conf` from the host to the container.

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

To make it work, puppet must run twice on all the nodes (because of the way resource collection works).\
`agent_regex` will only match nodes within the same Puppet environment (i.e. on test you won't be able match a node from the production environment). You can use `agent_list` if you need to match names across different environments.

```puppet
nomad_cni::macvlan::v4 {
  default:
    agent_regex => 'nomad0';
  'cni1':
    network => '192.168.1.0/24';
  'cni2':
    network => '172.16.2.0/22';
}
```

## Limitations

* currently only IPv4 is supported
* currently only `macvlan` plugin is supported (maybe macvlan is all we need?)
* there is no segregation at the moment: containers from one CNI can connect to containers on another CNI. On the other side this is a proof that routing is working like a charm. I still need to elaborate
* unit test is always on my mind, but it's not yet ready
