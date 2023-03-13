#!/bin/bash
#
# Configure VXLAN and Bridge interfaces
#
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

usage() {
    echo "Usage: $(basename $0) --force --id 8345"
    echo ""
    echo "    -h | --help    Print this help and exit"
    echo "    -f | --force   Force IP configuration"
    echo "    -a | --all     Processes all the configuration files"
    echo "    -i | --id      Processes the file with the specific VXLAN ID"
    echo "    -p | --purge   Purge VXLANs without a proper configuration file"
    echo "    -s | --silent  Print only errors"
    echo "         --systemd Run as a systemd service"
    echo ""
    exit
}

ifaces_down() {
    vxlan_id=$1
    ip link delete vxbr$vxlan_id &>/dev/null || true
    ip link delete vxlan$vxlan_id &>/dev/null || true
}

vxlan_up() {
    vxlan_id=$1
    $iface=$2
    vxlan_ip=$3
    ip link add vxlan$vxlan_id type vxlan id $vxlan_id dev $iface dstport 4789 local $vxlan_ip
    ip link set dev vxlan$vxlan_id up
}

populate_bridge_db() {
    vxlan_id=$1
    remote_ip_array=$2
    for remote_ip in $remote_ip_array; do
        bridge fdb append 00:00:00:00:00:00 dev vxlan$vxlan_id dst $remote_ip
    done
}

bridge_up() {
    vxlan_id=$1
    vxlan_ip=$2
    vxlan_netmask=$3
    brctl addbr vxbr$vxlan_id
    brctl addif vxbr$vxlan_id vxlan$vxlan_id
    ip addr add $vxlan_ip/$vxlan_netmask dev vxbr$vxlan_id
    ip link set up dev vxbr$vxlan_id
}

purge_unused() {
    vxlan_ifaces_up=$(ip -o link show | awk -F': ' '/vxlan[0-9]+:/{sub("vxlan", ""); print $2}')
    for vxlan_iface in $vxlan_ifaces_up; do
        if ! test -f "/etc/cni/vxlan.d/vxlan${vxlan_iface}.conf"; then
            ip link delete vxbr$vxlan_iface &>/dev/null || true
            ip link delete vxlan$vxlan_iface &>/dev/null || true
        fi
    done
}

check_status() {
    vxlan_id=$1
    vxlan_ip=$2
    if ip address show dev vxbr$vxlan_id &>/dev/null && ip address show dev vxlan$vxlan_id &>/dev/null && fping -c1 -t500 $vxlan_ip &>/dev/null; then
        return 0
    else
        return 1
    fi
}

OPTS=$(getopt -o "h,f,a,i:,s,p" --longoptions "help,force,all,id:,silent,purge,systemd" -- "$@")
eval set -- "$OPTS"

while true; do
    case "$1" in
    -h | --help)
        usage
        exit 3
        ;;
    -f | --force)
        FORCE="yes"
        ;;
    -a | --all)
        ALL="yes"
        ;;
    -i | --id)
        shift
        ID="$1"
        ;;
    -p | --purge)
        PURGE="yes"
        ;;
    -s | --silent)
        SILENT="yes"
        ;;
    --systemd)
        SYSTEMD="yes"
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

if [ -n "$ALL" ] && [ -n "$ID" ]; then
    echo "ERROR: You can't use --all and --id at the same time"
    usage
elif [ -z "$ALL" ] && [ -z "$ID" ] && [ -z "$PURGE" ]; then
    echo "ERROR: You must use --all, --id or --purge"
    usage
fi

if [ -n $ALL ]; then
    cfgArray=("/etc/cni/vxlan.d/vxlan*.conf")
elif [ -n $ID ]; then
    cfgArray=("/etc/cni/vxlan.d/vxlan_$ID.conf")
fi

if [ -n "$SILENT" ]; then
    REDIRECT="/dev/null"
else
    REDIRECT="$(tty)"
fi

if [ -n "$PURGE" ]; then
    purge_unused
    exit 0
fi

for vxlan in $cfgArray; do
    if [ -f $vxlan ]; then
        source $vxlan
        if [ -z "$vxlan_id" ] || [ -z "$vxlan_ip" ] || [ -z "$vxlan_netmask" ] || [ -z "$iface" ]; then
            echo "ERROR: vxlan configuration file $vxlan is not valid"
            exit 1
        fi

        if [ -n "$FORCE" ]; then
            if [ -z $SYSTEMD ]; then
                echo "Configuring VXLAN $vxlan_id" >$REDIRECT
            else
                echo "Configuring VXLAN $vxlan_id"
            fi
            ifaces_down $vxlan_id
            vxlan_up $vxlan_id $iface $vxlan_ip
            populate_bridge_db $vxlan_id $remote_ip_array
            bridge_up $vxlan_id $vxlan_ip $vxlan_netmask
        else
            if check_status $vxlan_id $vxlan_ip; then
                if [ -z $SYSTEMD ]; then
                    echo "VXLAN $vxlan_id is already configured" >$REDIRECT
                else
                    echo "VXLAN $vxlan_id is already configured"
                fi
            else
                if [ -z $SYSTEMD ]; then
                    echo "Configuring VXLAN $vxlan_id" >$REDIRECT
                else
                    echo "Configuring VXLAN $vxlan_id"
                fi
                ifaces_down $vxlan_id
                vxlan_up $vxlan_id $iface $vxlan_ip
                populate_bridge_db $vxlan_id $remote_ip_array
                bridge_up $vxlan_id $vxlan_ip $vxlan_netmask
            fi
        fi
    fi
done
