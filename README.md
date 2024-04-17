# Nomad CNI

## Table of Contents

1. [Overview](#overview)
2. [Requirements and notes](#requirements-and-notes)
3. [What this module affects](#what-this-module-affects)
4. [Architecture diagram](#architecture-diagram)
5. [Usage and examples](#usage-and-examples)
    1. [Install the CNI components](#install-the-cni-components)
    2. [Create a bunch of CNI networks](#create-a-bunch-of-cni-networks)
    3. [Minimum networks](#minimum-networks)
6. [Firewall](#firewall)
    1. [NAT](#nat)
    2. [VXLAN traffic](#vxlan-traffic)
    3. [CNIs segregation](#cnis-segregation)
    4. [CNIs interconnection](#cnis-interconnection)
7. [Add CNIs to Nomad](#add-cnis-to-nomad)
    1. [add host_network using VoxPupuli Nomad module](#add-host_network-using-voxpupuli-nomad-module)
    1. [Nomad job example](#nomad-job-example)
8. [Register your services to Consul](#register-your-services-to-consul)
9. [Limitations](#limitations)

## Overview

This module leverages the configuration of the CNI networks, using VXLAN technology and macvlan network driver on the Nomad agents.

Whilst other CNI operators uses key pair databases to store/retrieve the configurations, this module does two things:

1. use your Puppet hieradata backend (whatever it is)
2. splits the network in multiple segment, and assigns one segment for each agent. There is a function which can determine the size of the networks based on the number of agents, otherwise the `min_networks` parameter can be used to create more networks (this comes to hand if you want to increase the size of your cluster, without disruptions).

The module will also create a Bridge interface and a VXLAN interface on each Agent and for each CNI network, and the VXLANs will be interconnected and bridged with the host network.

## Requirements and notes

In addition to the requirements listed in `metadata.json`, **this module requires PuppetDB**.

You need to enable IP forward:

```bash
# cat /proc/sys/net/ipv4/ip_forward
1
```

The CNI configuration has a stanza for the [DNS settings](https://www.cni.dev/plugins/current/main/vlan/), but these settings won't work with Nomad. If necessary you can specify the settings for the [DNS in Nomad](https://developer.hashicorp.com/nomad/docs/job-specification/network#dns-1).

## What this module affects <a name="what-this-module-affects"></a>

* Installs the CNI network plugins (via url)
* Installs configuration/scripts for every CNI network (`/opt/cni/vxlan/.d/{un,mult}icast.d/*.sh`)
* Creates a Bridge and a VXLAN for every CNI network (managed via custom script)
* Optionally, segregates and interconnects CNIs (by default they're open and interconnected)

## Architecture diagram

![Could not fetch Nomad diagram!](https://cds.geant.org/pub/Nomad_cluster_small.jpg)

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

`agent_regex` will only match nodes within the same Puppet environment. Alternatively you can use `agent_list` to supply a list of nomad agents.

Using the following resource declaration you can setup two CNI networks, using the unicast vxlan technology:

```puppet
nomad_cni::bridge::unicast::v4 {
  default:
    agent_regex => 'nomad0';
  'cni1':
    network => '192.168.1.0/24';
  'cni2':
    network => '172.16.2.0/22';
}
```

Multicast shuold be better, but in my environment it wasn't reliable. Feel free to experiment at your own risk.

### Minimum networks

in most cases it is unlikely to use all the IPs on the same Agent. For instance a 24 bit network, split by 3 agents, will give 83 IPs per Agent.

You may decide to overcommit the number of networks, to foresee and allow a seamless extension of the Nomad cluster. If you do not use this parameter, when you extend the cluster, the CNI needs to be reconfigured on all the agents, and you'll experience an outage (the containers loose connectivity and need to be respawned).

In the example below the 24 bit network will be split by 10, and it will assign 24 IPs for each network, regardless of the number of agents:

```puppet
nomad_cni::bridge::unicast::v4 {
  default:
    min_networks => 10,
    agent_regex  => 'nomad0';
  'cni10':
    network => '192.168.3.0/24';
  'cni20':
    network => '172.16.4.0/22';
}
```

## Firewall

The firewall settings are applied via the module `puppetlabs/firewall`.

The rules are being created under a custom chain, so they can be purged without affecting the default chain.

### NAT

`manage_firewall_nat` is set to `true`. This is kind of mandatory. Without this rule the containers won't be able to connect outside.

### VXLAN traffic

If your firewall is set to drop connections that are not specifically declared, you can set `manage_firewall_vxlan` to `true`, to open UDP port 4789 among the Nomad Agents.

### CNIs segregation

By default all CNIs are interconneccted. CNIs segregation is achieved by setting `cni_cut_off` to `true`:

```puppet
class { 'nomad_cni':
  cni_cut_off  => true
}
```

### CNIs interconnection

If you applied CNI segregation (`cni_cut_off` set to `true`), you can interconnect some of them using the following code:

```puppet
nomad_cni::cni_connect { ['cni1', 'cni2']: }
```

If you need encryption, or you need to interconnect only certain services within the CNI, you could use [Consul Connect](https://developer.hashicorp.com/consul/docs/connect)

## Add CNIs to Nomad

The client stanza of the Agent configuration has a section called `host_network`.

Using the host_network, the job will be registered on Consul using the IP belonging to the host_network and will open a socket only on the host_network.

If you do not follow these steps the socket will be open either on the Agent IP, on the bridge, and on the Container, and you defeat the purpose of using CNI.

### add host_network using VoxPupuli Nomad module

This module provides a function that can be used to pass the `host_network` parameter to [VoxPupuli Nomad Module](https://forge.puppet.com/modules/puppet/nomad).

Assuming that the Nomad agent is listening on `eth0`, you can add the following key in your Nomad configuration hash

```puppet
host_network => nomad_cni::host_network_v4('eth0')
```

as a result, you'll get something like the following in the agent configuration

```json
"host_network": [
  {
    "public": {
      "cidr": "183.184.185.186/22",
      "interface": "eth0"
    }
  },
  {
    "foo": {
      "cidr": "192.168.2.1/24",
      "interface": "vxbr11882895"
    }
  },
  {
    "bar": {
      "cidr": "192.168.3.1/24",
      "interface": "vxbr5199537"
    }
  },
  ... and so on ...
]
```

If you have dual stack IP configuration, the network that it's not defined will be the default network for your jobs.

If you want to default to your host `ipv4`, you need to include `ipv6` instead, and you can do as following:

```puppet
host_network => nomad_cni::host_network_v4('eth0', 'v6')
```

### Nomad job example

If you have a `host_network` called `foo`, this is how the network stanza looks like in your job (as you can see, you no longer need to use dynamic ports with CNI isolated networks)

```hcl
network {
  mode = "cni/foo"
  port "grafana" {
    static       = 3000
    host_network = "foo"
  }
}
```

### Register your services to Consul

If you register the service at `task` level, using the default settings, Nomad will register to Consul the IP of gateway of the CNI (instead of the IP of the container) and the service will be unreachable.

The service block must be defined at `group` level, and it must contain `address_mode = "alloc"` either in the `service` block and in the `check` block:

```hcl
service {
  name         = "test-service-http"
  provider     = "consul"
  address_mode = "alloc"
  port         = "http"
  tags         = ["tcp"]
  check {
    name         = "http_tcp_check"
    address_mode = "alloc"
    type         = "tcp"
    port         = "http"
    interval     = "5s"
    timeout      = "2s"
  }
}
```

## Limitations

* only IPv4 is currently supported
* changelog not yet handled
* temporarily suspended the spec test. Only the linting check is running
* feel free to test it on RedHat, to contribute and raise issues
