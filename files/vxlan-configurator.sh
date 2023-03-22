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

purge_stale_ifaces() {
    vxlan_ifaces_up=$(ip -o link show | awk -F': ' '/vxlan[0-9]+:/{sub("vxlan", ""); print $2}')
    for vxlan_iface in $vxlan_ifaces_up; do
        if ! grep -qrw $vxlan_iface /etc/cni/vxlan/{multicast,unicast}.d; then
            ip link delete vxbr$vxlan_iface &>/dev/null || true
            ip link delete vxlan$vxlan_iface &>/dev/null || true
        fi
    done
}

purge_stale_services() {
    configured_services=$(systemctl list-units cni-id@* --all -l --no-pager --no-legend | awk '{print $NF}')
    for srv in $configured_services; do
        if ! test -f "/etc/cni/vxlan/multicast.d/${srv}.sh" && ! test -f "/etc/cni/vxlan/unicast.d/${srv}.sh"; then
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

if [ -n $STARTED_BY_SYSTEMD ]; then
    NOISY='yes'
else
    tty -s && NOISY='yes'
fi

shopt -s nullglob
if [ "$lower_name" == 'all' ]; then
    scriptArray=(/etc/cni/vxlan/*icast.d/*.sh)
else
    scriptArray=(/etc/cni/vxlan/*icast.d/$NAME.sh)
fi

# == MAIN ==
#
# we parse the scripts and bring up/down the vxlan and bridge
#
for script in ${scriptArray[*]}; do
    if [ -f $script ]; then
        vxlan_name=$(basename $script | cut -d'.' -f1)
        source <(grep vxlan_i.= test_cni_1.sh) # set vxlan_id and vxlan_ip
        if [[ "$script" == *"unicast"* ]]; then
            TYPE="unicast"
        elif [[ "$script" == *"multicast"* ]]; then
            TYPE="multicast"
        fi
        if [ -n "$FORCE" ]; then
            if [ "$lower_status" == "up" ]; then
                [ -n $NOISY ] && echo "vxlan $vxlan_id - cni $vxlan_name: not configured, bringing up vxlan"
                $script
            else
                [ -n $NOISY ] && echo "vxlan $vxlan_id - cni $vxlan_name: bringing down vxlan and bridge"
                ip address show dev vxlan$vxlan_id &>/dev/null && ip link delete vxlan$vxlan_id
                ip address show dev vxbr$vxlan_id &>/dev/null && ip link delete vxbr$vxlan_id
            fi
        else
            # from systemd we ONLY use force. We don't need any check here
            if check_status $vxlan_id $vxlan_ip; then
                # do not print if not a tty (cron job)
                [ -n $NOISY ] && echo "VXLAN $vxlan_id is already configured"
            else
                # now we bring it up only if status was set to up
                if [ "$lower_status" == "up" ]; then
                    [ -n $NOISY ] && echo "vxlan $vxlan_id - cni $vxlan_name: not configured, bringing up vxlan"
                    $script
                else
                    [ -n $NOISY ] echo "vxlan $vxlan_id - cni $vxlan_name: bringing down vxlan and bridge"
                    ip address show dev vxlan$vxlan_id &>/dev/null && ip link delete vxlan$vxlan_id
                    ip address show dev vxbr$vxlan_id &>/dev/null && ip link delete vxbr$vxlan_id
                fi
            fi
        fi
    else
        echo "ERROR: vxlan script $script does not exist"
        exit 1
    fi
done
