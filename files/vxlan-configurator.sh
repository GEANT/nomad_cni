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
    echo "Usage: $(basename $0) --force --status up --name my_cni"
    echo ""
    echo "    -h | --help    Print this help and exit"
    echo "    --name    name/all: Configure the specific CNI, or all if all/ALL is specified"
    echo "    --status  up/down: Bring VXLAN and Bridge down"
    echo "    --type    multicast/unicast: Use multicast of unicast"
    echo "    --force   Force IP configuration"
    echo "    --purge   Purge VXLANs and systemd service without a matching configuration file"
    echo ""
    exit 3
}

ifaces_down() {
    vxlan_id=$1
    ip address show dev vxbr$vxlan_id &>/dev/null && ip link delete vxbr$vxlan_id || true
    ip address show dev vxlan$vxlan_id &>/dev/null && ip link delete vxlan$vxlan_id || true
}

vxlan_config() {
    vxlan_id=$1
    iface=$2
    vxlan_ip=$3
    type=$4
    if [ "$type" == "multicast" ]; then
        ip link add vxlan$vxlan_id type vxlan id $vxlan_id dev $iface dstport 4789 group $multicast_group
    else
        ip link add vxlan$vxlan_id type vxlan id $vxlan_id dev $iface dstport 4789 local $vxlan_ip
    fi
}

populate_bridge_db() {
    vxlan_id=$1
    remote_ip_array=$2
    is_systemd=$3
    cni_name=$4
    for remote_ip in ${remote_ip_array[*]}; do
        [ "$is_systemd" == "STARTED_BY_SYSTEMD" ] && echo "vxlan $vxlan_id - cni $cni_name: adding $remote_ip to bridge DB"
        bridge fdb append 00:00:00:00:00:00 dev vxlan$vxlan_id dst $remote_ip
    done
}

bridge_up() {
    vxlan_id=$1
    vxlan_ip=$2
    vxlan_netmask=$3
    ip link set dev vxlan$vxlan_id up # bring up the vxlan interface after populating the bridge db
    brctl addbr vxbr$vxlan_id
    brctl addif vxbr$vxlan_id vxlan$vxlan_id
    ip address add $vxlan_ip/$vxlan_netmask dev vxbr$vxlan_id
    ip link set up dev vxbr$vxlan_id
}

purge_stale_ifaces() {
    vxlan_ifaces_up=$(ip -o link show | awk -F': ' '/vxlan[0-9]+:/{sub("vxlan", ""); print $2}')
    for vxlan_iface in $vxlan_ifaces_up; do
        if ! grep -qrw vxlan_id=$vxlan_iface /etc/cni/vxlan/{multicast,unicast}.d; then
            ip link delete vxbr$vxlan_iface &>/dev/null || true
            ip link delete vxlan$vxlan_iface &>/dev/null || true
        fi
    done
}

purge_stale_services() {
    configured_services=$(systemctl list-units cni-id@* --all -l --no-pager --no-legend | awk '{print $NF}')
    for srv in $configured_services; do
        if ! test -f "/etc/cni/vxlan/multicast.d/${srv}.conf" && ! test -f "/etc/cni/vxlan/unicast.d/${srv}.conf"; then
            systemctl disable cni-id@${srv}.service
            systemctl stop cni-id@${srv}.service
            rm -f /etc/systemd/system/cni-id@${srv}.service
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

if [ -z "$NAME" ] && [ -z "$PURGE" ]; then
    echo -e "\nERROR: Either --name or --purge must be used\n"
    usage
elif [ -n "$NAME" ] && [ -n "$PURGE" ]; then
    echo -e "\nERROR: Only one of --name or --purge can be used\n"
    usage
elif [ -n "$PURGE" ]; then
    if [ $parameters -gt 1 ]; then
        echo -e "\nERROR: You must use --purge alone\n"
        usage
    fi
    purge_stale_ifaces
    purge_stale_services
    exit 0
elif [ -z "$STATUS" ]; then
    echo -e "\nERROR: You must use --status up or --status down\n"
    usage
fi

lower_status=$(echo $STATUS | tr '[:upper:]' '[:lower:]')
lower_name=$(echo $NAME | tr '[:upper:]' '[:lower:]')

if [ "$lower_status" != "up" ] && [ "$lower_status" != "down" ]; then
    echo -e "ERROR: You must use --status up or --status down\n"
    usage
fi

shopt -s nullglob
if [ "$lower_name" == 'all' ]; then
    cfgArray=(/etc/cni/vxlan/*.d/*.conf)
else
    cfgArray=(/etc/cni/vxlan/*.d/$NAME.conf)
fi

# == MAIN ==
#
# we parse all the configuration files and we bring up/down the vxlan and bridge
#
for vxlan in ${cfgArray[*]}; do
    if [ -f $vxlan ]; then
        source $vxlan
        if [ -z "$vxlan_id" ] || [ -z "$vxlan_ip" ] || [ -z "$vxlan_netmask" ] || [ -z "$iface" ]; then
            echo "ERROR: vxlan configuration file $vxlan is not valid"
            exit 1
        fi
        if [[ "$vxlan" == *"unicast"* ]]; then
          TYPE="unicast"
        elif [[ "$vxlan" == *"multicast"* ]]; then
          TYPE="multicast"
        fi

        if [ -n "$FORCE" ]; then
            [ -n $STARTED_BY_SYSTEMD ] && echo "vxlan $vxlan_id - cni $NAME: bringing down vxlan and bridge"
            ifaces_down $vxlan_id
            # now we bring it up only if status was set to up
            if [ "$lower_status" == "up" ]; then
                [ -n $STARTED_BY_SYSTEMD ] && echo "vxlan $vxlan_id - cni $NAME: not configured, bringing up vxlan"
                vxlan_config $vxlan_id $iface $vxlan_ip $TYPE
                if [ "$TYPE" == "unicast" ]; then
                    [ -n $STARTED_BY_SYSTEMD ] && echo "vxlan $vxlan_id - cni $NAME: adding remote IPs to bridge db"
                    populate_bridge_db $vxlan_id $remote_ip_array 'STARTED_BY_SYSTEMD' $NAME
                fi
                [ -n $STARTED_BY_SYSTEMD ] && echo "vxlan $vxlan_id - cni $NAME: bringing up bridge"
                bridge_up $vxlan_id $vxlan_ip $vxlan_netmask
            fi
        else
            # from systemd we only use force. We don't need any check here
            if check_status $vxlan_id $vxlan_ip; then
                # do not print if not a tty (cron job)
                tty -s && echo "VXLAN $vxlan_id is already configured"
            else
                ifaces_down $vxlan_id
                # now we bring it up only if status was set to up
                if [ "$lower_status" == "up" ]; then
                    vxlan_config $vxlan_id $iface $vxlan_ip $TYPE
                    [ "$TYPE" == "unicast" ] && populate_bridge_db $vxlan_id $remote_ip_array 'STARTED_BY_SYSTEMD' $NAME
                    bridge_up $vxlan_id $vxlan_ip $vxlan_netmask
                fi
            fi
        fi
    else
        echo "ERROR: vxlan configuration file $vxlan does not exist"
        exit 1
    fi
done
