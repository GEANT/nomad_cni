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
    echo "    --force   Force IP configuration"
    echo "    --purge   Purge VXLANs and systemd service without a matching script"
    echo ""
    exit 3
}

ifaces_down() {
    vxlan_id=$1
    ip address show dev vxbr$vxlan_id &>/dev/null && ip link delete vxbr$vxlan_id || true
    ip address show dev vxlan$vxlan_id &>/dev/null && ip link delete vxlan$vxlan_id || true
}

purge_stale_ifaces() {
    vxlan_ifaces_up=$(ip -o link show | awk -F': ' '/vxlan[0-9]+:/{sub("vxlan", ""); print $2}')
    for vxlan_iface in $vxlan_ifaces_up; do
        if ! grep -qrw $vxlan_iface /etc/vxlan/{multicast,unicast}.d; then
            ip link delete vxbr$vxlan_iface &>/dev/null || true
            ip link delete vxlan$vxlan_iface &>/dev/null || true
        fi
    done
}

purge_stale_services() {
    configured_services=$(systemctl list-units cni-id@* --all -l --no-pager --no-legend | awk '{print $NF}')
    for srv in $configured_services; do
        if ! test -f "/etc/vxlan/multicast.d/${srv}.sh" && ! test -f "/etc/vxlan/unicast.d/${srv}.sh"; then
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
        FORCE="bofh"
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
        PURGE="bofh"
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

if [ -n "$PURGE" ]; then
    if [ $parameters -gt 0 ]; then
        echo -e "\nERROR: --purge cannot be used with other options\n"
        usage
    fi
    purge_stale_ifaces
    purge_stale_services
    exit 0
elif [ $parameters -lt 2 ]; then
    echo -e "\nERROR: You must use --name <cni_name> and --status <up>/<down>\n"
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
    scriptArray=(/etc/vxlan/*icast.d/*.sh)
else
    scriptArray=(/etc/vxlan/*icast.d/$NAME.sh)
fi

if [ -n $STARTED_BY_SYSTEMD ] || [ -z $STARTED_BY_CRON ]; then
    NOISY='bofh'
fi

# == MAIN ==
#
# we parse the scripts and bring up/down the vxlan and the bridge
#
for script in ${scriptArray[*]}; do
    vxlan_name=$(basename $script | cut -d'.' -f1)
    source <(grep vxlan_i.= $script) # set vxlan_id and vxlan_ip
    if [[ "$script" == *"unicast"* ]]; then
        TYPE="unicast"
    elif [[ "$script" == *"multicast"* ]]; then
        TYPE="multicast"
    fi
    if [ -n "$FORCE" ]; then
        if [ "$lower_status" == "up" ]; then
            [ -n $NOISY ] && echo "vxlan $vxlan_id - cni $vxlan_name not configured, bringing up vxlan"
            $script
        else
            [ -n $NOISY ] && echo "vxlan $vxlan_id - cni $vxlan_name bringing down vxlan and bridge"
            ifaces_down $vxlan_id
        fi
    else
        if check_status $vxlan_id $vxlan_ip; then
            [ -n $NOISY ] && echo "VXLAN $vxlan_id is already configured"
        else
            if [ "$lower_status" == "up" ]; then
                [ -n $NOISY ] && echo "vxlan $vxlan_id - cni $vxlan_name not configured, bringing up vxlan"
                $script
            else
                [ -n $NOISY ] echo "vxlan $vxlan_id - cni $vxlan_name bringing down vxlan and bridge"
                ifaces_down $vxlan_id
            fi
        fi
    fi
done
