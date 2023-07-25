#!/bin/bash
#
# Configure VXLAN and Bridge interfaces
#
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR='/opt/cni/vxlan'
export PATH BASE_DIR

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

usage() {
    echo "Usage: $(basename $0) --force --status <up>/<down> --name <my_cni>"
    echo ""
    echo "    -h|--help  Print this help and exit"
    echo "    --name     [name/all] Configure the specific CNI, or all if all/ALL is specified"
    echo "    --status   [up/down/check] Bring VXLAN and Bridge down"
    echo "    --force    Force IP configuration"
    echo "    --purge    Purge VXLANs and systemd service without a matching script"
    echo ""
    exit 3
}

ifaces_down() {
    vxlan_id=$1
    ip link delete vxbr$vxlan_id || true
    ip link delete vxlan$vxlan_id || true
}

purge_stale_ifaces() {
    vxlan_ifaces_up=$(ip -o link show | awk -F': ' '/vxlan[0-9]+:/{sub("vxlan", ""); print $2}')
    for vxlan_iface in $vxlan_ifaces_up; do
        if ! grep -qrw $vxlan_iface $BASE_DIR/unicast.d; then
            ip link delete vxbr$vxlan_iface &>/dev/null || true
            ip link delete vxlan$vxlan_iface &>/dev/null || true
        fi
    done
}

purge_stale_services() {
    configured_services=$(systemctl list-units cni-id@* --all --full --no-pager --no-legend | awk '{print $NF}')
    for srv in $configured_services; do
        if ! test -f "${BASE_DIR}/unicast.d/${srv}.sh"; then
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
    elif ip address show dev vxbr$vxlan_id &>/dev/null && ip address show dev vxlan$vxlan_id &>/dev/null && ! fping -c1 -t500 $vxlan_ip &>/dev/null; then
        return 1
    else
        return 2
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

if [ "$lower_status" != "up" ] && [ "$lower_status" != "down" ] && [ "$lower_status" != "check" ]; then
    echo -e "ERROR: You must use --status up or --status down\n"
    usage
fi

if [ -n "$STARTED_BY_SYSTEMD" ] || [ -z "$STARTED_BY_CRON" ]; then
    ECHO_CMD='echo'
else
    ECHO_CMD='logger -t CNI-VXLAN-wizard'
fi

shopt -s nullglob
if [ "$lower_name" == 'all' ]; then
    scriptArray=($BASE_DIR/*icast.d/*.sh)
else
    scriptArray=($BASE_DIR/*icast.d/$NAME.sh)
fi

EXIT_STATUS=0

# == MAIN ==
#
# we parse the scripts and bring up/down the vxlan and the bridge
#
for script in ${scriptArray[*]}; do
    vxlan_name=$(basename $script | cut -d'.' -f1)
    source <(grep -E "vxlan_[i|n].*=" $script) # set vxlan_id, vxlan_ip and vxlan_network
    if [ "$lower_status" == "check" ]; then
        check_status $vxlan_id $vxlan_ip
        vxlan_status="$?"
        if [ $vxlan_status == "0" ]; then
            $ECHO_CMD "VXLAN $vxlan_id is up"
        elif [ $vxlan_status == "1" ]; then
            $ECHO_CMD "VXLAN $vxlan_id is up but $vxlan_ip not reachable"
            EXIT_STATUS=1
        else
            $ECHO_CMD "VXLAN $vxlan_id is down"
            EXIT_STATUS=2
        fi
    elif [ -n "$FORCE" ]; then
        if [ "$lower_status" == "up" ]; then
            $ECHO_CMD "VXLAN $vxlan_id - CNI $vxlan_name not configured, bringing up vxlan"
            $script
        else
            $ECHO_CMD "VXLAN $vxlan_id - CNI $vxlan_name bringing down vxlan and bridge"
            ifaces_down $vxlan_id
        fi
    else
        check_status $vxlan_id $vxlan_ip
        vxlan_status="$?"
        if [ $vxlan_status == "0" ]; then
            if [ -z "$STARTED_BY_SYSTEMD" ] || [ -n "$STARTED_BY_CRON" ]; then # we dont want to pollute the logs
                $ECHO_CMD "VXLAN $vxlan_id is already configured"
            fi
        else
            if [ "$lower_status" == "up" ]; then
                if [ $vxlan_status == "1" ]; then
                    # the interface is up but the IP is not reachable
                    $ECHO_CMD "VXLAN $vxlan_id - CNI $vxlan_name not reachable, bringing up vxlan IP $vxlan_ip"
                    ip addr add $vxlan_network dev vxbr$vxlan_id &>/dev/null || true  # bring IP up and ignore errors
                    sleep .5  # is this really needed?
                    if ! fping -c1 -t500 $vxlan_ip &>/dev/null; then
                        $ECHO_CMD "VXLAN $vxlan_id - CNI $vxlan_name still not working. Reloading vxlan"
                        $script  # reload vxlan
                    else
                        $ECHO_CMD "VXLAN $vxlan_id - CNI $vxlan_name is now working"
                    fi
                else
                    # the interface is down
                    $ECHO_CMD "VXLAN $vxlan_id - CNI $vxlan_name not configured, bringing up vxlan"
                    $script # reload vxlan
                fi
            else
                $ECHO_CMD echo "VXLAN $vxlan_id - CNI $vxlan_name bringing down vxlan and bridge"
                ifaces_down $vxlan_id
            fi
        fi
    fi
done

exit $EXIT_STATUS
