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
    echo "Usage: $(basename $0) --force --id 8345 or $(basename $0) --force --id all"
    echo ""
    echo "    -h | --help    Print this help and exit"
    echo "    --name    name/all: Configure the specific CNI, or all if all/ALL is specified"
    echo "    --status  up/down: Bring VXLAN and Bridge down"
    echo "    --force   Force IP configuration"
    echo "    --purge   Purge VXLANs without a matching configuration file"
    echo ""
    exit 3
}

ifaces_down() {
    vxlan_id=$1
    ip link delete vxbr$vxlan_id &>/dev/null || true
    ip link delete vxlan$vxlan_id &>/dev/null || true
}

vxlan_up() {
    vxlan_id=$1
    iface=$2
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
    ip address add $vxlan_ip/$vxlan_netmask dev vxbr$vxlan_id
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

parameters=0
OPTS=$(getopt -o "h" --longoptions "help,name:,status:,force,purge" -- "$@")
eval set -- "$OPTS"

while true; do
    case "$1" in
    -h | --help)
        usage
        ;;
    --force)
        FORCE="yes"
        ;;
    --name)
        shift
        NAME="$1"
        ((parameters++))
        ;;
    --status)
        shift
        STATUS="$1"
        ((parameters++))
        ;;
    --purge)
        PURGE="yes"
        ((parameters++))
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

# check if the script is triggered by systemd
if [ "$(ps -o comm= $PPID)" == systemd ]; then
    SYSTEMD="yes"
fi

if [ -n "$PURGE" ]; then
    if [ $parameters -gt 1 ]; then
        echo -e "ERROR: You must use --purge alone\n"
        usage
    fi
    purge_unused
    exit 0
elif [ -z "$STATUS" ]; then
    echo -e "ERROR: You must use --status up --status down\n"
    usage
elif [ -z "$NAME" ] && [ -z "$PURGE" ]; then
    echo -e "ERROR: You must use --id or --purge\n"
    usage
fi

lower_status=$(echo $STATUS | tr '[:upper:]' '[:lower:]')
lower_name=$(echo $NAME | tr '[:upper:]' '[:lower:]')

if [ "$lower_status" != "up" ] && [ "$lower_status" != "down" ]; then
    echo -e "ERROR: You must use --status up or --status down\n"
    usage
fi

if [ "$lower_name" == 'all' ]; then
    cfgArray=("/etc/cni/vxlan.d/*.conf")
else
    cfgArray=("/etc/cni/vxlan.d/$NAME.conf")
fi

for vxlan in $cfgArray; do
    if [ -f $vxlan ]; then
        source $vxlan
        if [ -z "$vxlan_id" ] || [ -z "$vxlan_ip" ] || [ -z "$vxlan_netmask" ] || [ -z "$iface" ]; then
            echo "ERROR: vxlan configuration file $vxlan is not valid"
            exit 1
        fi

        if [ -n "$FORCE" ]; then
            ifaces_down $vxlan_id
        else
            # from crontab we do not use force option, so we check if vxlan is already configured
            if check_status $vxlan_id $vxlan_ip; then
                if [ -n "$SYSTEMD" ]; then
                    # print if systemd (tty does not work)
                    echo "VXLAN $vxlan_id is already configured"
                else
                    # do not print if not a tty (cron job)
                    tty -s && echo "VXLAN $vxlan_id is already configured"
                fi
                exit
            else
                ifaces_down $vxlan_id
            fi
        fi
        if [ "$lower_status" == "up" ]; then
            vxlan_up $vxlan_id $iface $vxlan_ip
            populate_bridge_db $vxlan_id $remote_ip_array
            bridge_up $vxlan_id $vxlan_ip $vxlan_netmask
        fi
    else
        echo "ERROR: vxlan configuration file $vxlan does not exist"
        exit 1
    fi
done
