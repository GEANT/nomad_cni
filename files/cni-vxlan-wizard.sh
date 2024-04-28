#!/bin/bash
#
# Configure VXLAN and Bridge interfaces
#
source /opt/cni/params.conf
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

if [ -n "$STARTED_BY_SYSTEMD" ] || [ -z "$STARTED_BY_CRON" ]; then
    echo_cmd='echo'
else
    echo_cmd='logger -t CNI-VXLAN-wizard'
fi

[ $(id -u) -ne 0 ] && {
    echo "ERROR: This script must be run as root"
    exit 1
}

usage() {
    echo "Usage: $(basename $0) [--force] [--purge] --status <up>/<down>/<check> --name <cni_name>"
    echo ""
    echo "    -h|--help    Print this help and exit"
    echo "    -n|--name    (name/all) Configure the named CNI, or all CNIs if all/ALL is specified"
    echo "    -s|--status  (up/down/check) Bring VXLAN and Bridge down"
    echo "    -f|--force   Force IP re-configuration"
    echo "    -p|--purge   Purge VXLANs and systemd services without a matching script"
    echo "    -v|--vip     Bring interfaces down on BACKUP Keepalived node"
    echo ""
    exit 3
}

ifaces_down() {
    vxlan_id=$1
    for iface in br vx; do
        if ip link show $iface$vxlan_id &>/dev/null; then
            ip link delete $iface$vxlan_id || true
        else
            $echo_cmd "Interface $iface$vxlan_id does not exist"
        fi
    done
}

purge_stale_ifaces() {
    vxlan_ifaces_up=$(ip -o link show | awk -F': ' '/vx[0-9]+:/{sub("vx", ""); print $2}')
    for vxlan_iface in $vxlan_ifaces_up; do
        if ! grep -qrw $vxlan_iface $base_dir/unicast.d; then
            ip link delete br$vxlan_iface &>/dev/null || true
            ip link delete vx$vxlan_iface &>/dev/null || true
        fi
    done
}

purge_stale_services() {
    configured_services=$(systemctl list-units cni-id@* --all --full --no-pager --no-legend | awk '{print $NF}')
    for srv in $configured_services; do
        if ! test -f "${base_dir}/unicast.d/${srv}.sh"; then
            systemctl disable cni-id@${srv}.service
            systemctl stop cni-id@${srv}.service
            rm -f /etc/systemd/system/cni-id@${srv}.service
            systemctl daemon-reload
        fi
    done
}

check_status() {
    vxlan_id=$1
    vxlan_ip=$2
    vx_file="/sys/class/net/vx$vxlan_id/operstate"
    br_file="/sys/class/net/br$vxlan_id/operstate"
    str_match="Link detected: yes"
    if ethtool vx$vxlan_id 2>/dev/null | grep -q "$str_match" && ethtool br$vxlan_id 2>/dev/null | grep -q "$str_match"; then
    if grep -qw unknown $vx_file 2>/dev/null && grep -qw up $br_file 2>/dev/null; then
        if fping -c1 -t500 $vxlan_ip &>/dev/null; then
            return 0
        else
            return 1
        fi
    else
        return 2
    fi
}

parameters=0
opts=$(getopt -o "h,n:,s:,f,p,v" --longoptions "help,name:,status:,force,purge,vip" -- "$@")
eval set -- "$opts"

while true; do
    case "$1" in
    -h | --help)
        usage
        ;;
    -f | --force)
        force="bofh"
        ;;
    -n | --name)
        shift
        name="$1"
        ((parameters++))
        ;;
    -s | --status)
        shift
        status="$1"
        ((parameters++))
        ;;
    -p | --purge)
        purge="bofh"
        ;;
    -v | --vip)
        vip="bofh"
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

if [ -n "$vip" ] && [ -f /etc/keepalived/keepalived.conf ]; then
    if ! ip addr | grep -q " ${vip_address}/${vip_netmask}"; then
        # we are not the master. Let's revert status to down :)
        status="down"
        force="bofh"
    fi
fi

if [ -n "$purge" ]; then
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

lower_status=$(echo $status | tr '[:upper:]' '[:lower:]')
lower_name=$(echo $name | tr '[:upper:]' '[:lower:]')

if [ "$lower_status" != "up" ] && [ "$lower_status" != "down" ] && [ "$lower_status" != "check" ]; then
    echo -e "ERROR: You must use --status up or --status down\n"
    usage
fi

shopt -s nullglob
if [ "$lower_name" == 'all' ]; then
    confArray=($base_dir/*icast.d/*.conf)
else
    confArray=($base_dir/*icast.d/$name.conf)
fi

exit_status=0

# == MAIN ==
#
# we parse the scripts and bring up/down or check the vxlan and the bridge
#
for conf in ${confArray[*]}; do
    vxlan_name=$(basename -s .conf $conf)
    script=$(echo $conf | sed 's/\.conf$/.sh/')
    source $conf
    if [ "$lower_status" == "check" ]; then
        check_status $vxlan_id $vxlan_ip
        vxlan_status="$?"
        if [ $vxlan_status == "0" ]; then
            $echo_cmd "VXLAN $vxlan_id is up"
        elif [ $vxlan_status == "1" ]; then
            $echo_cmd "VXLAN $vxlan_id is up but $vxlan_ip not reachable"
            exit_status=1
        else
            $echo_cmd "VXLAN $vxlan_id is down"
            exit_status=2
        fi
    elif [ -n "$force" ]; then
        if [ "$lower_status" == "up" ]; then
            $echo_cmd "VXLAN $vxlan_id - CNI $vxlan_name not configured, bringing up vxlan"
            $script
        else
            $echo_cmd "VXLAN $vxlan_id - CNI $vxlan_name bringing down vxlan and bridge"
            ifaces_down $vxlan_id
        fi
    else
        check_status $vxlan_id $vxlan_ip
        vxlan_status="$?"
        if [ $vxlan_status == "0" ]; then
            if [ -z "$STARTED_BY_SYSTEMD" ] || [ -n "$STARTED_BY_CRON" ]; then # we dont want to pollute the logs
                $echo_cmd "VXLAN $vxlan_id is already configured"
            fi
        else
            if [ "$lower_status" == "up" ]; then
                if [ $vxlan_status == "1" ]; then
                    # the interface is up but the IP is not reachable
                    $echo_cmd "VXLAN $vxlan_id - CNI $vxlan_name not reachable, bringing up vxlan IP $vxlan_ip"
                    which nomad &>/dev/null && noprefixroute=noprefixroute                                  # this is a Nomad Agent and GW is remote
                    ip addr add $vxlan_ip/$vxlan_netmask dev br$vxlan_id $noprefixroute &>/dev/null || true # bring IP up and ignore errors
                    [ -z "$(ip route list $vxlan_ip/$vxlan_netmask)" ] && ip route add $vxlan_ip/$vxlan_netmask via $vip_address
                    if ! fping -c1 -t500 $vxlan_ip &>/dev/null; then
                        $echo_cmd "VXLAN $vxlan_id - CNI $vxlan_name still not working. Reloading vxlan"
                        $script # reload vxlan
                    else
                        $echo_cmd "VXLAN $vxlan_id - CNI $vxlan_name is now working"
                    fi
                else
                    # the interface is down
                    $echo_cmd "VXLAN $vxlan_id - CNI $vxlan_name not configured, bringing up vxlan"
                    $script # reload vxlan
                fi
            else
                $echo_cmd echo "VXLAN $vxlan_id - CNI $vxlan_name bringing down vxlan and bridge"
                ifaces_down $vxlan_id
            fi
        fi
    fi
done

exit $exit_status
