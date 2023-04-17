#!/bin/bash
#
# this script can be run manually, but it's normally triggered by a systemd
# service or by puppet and it's associated to a script under the directory
# /opt/cni/vlan/unicast.d, that creates the vxlan interface
#
PATH=/usr/sbin:/usr/bin:/sbin:/bin

