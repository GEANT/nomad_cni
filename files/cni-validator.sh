#!/bin/bash
#
# validate JSON files and ensure that the network is not duplicated
#
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

usage() {
    echo ""
    echo "Usage: $(basename $0) -n $192.168.1.0/24 -f /opt/cni/config/cni1.conflist -t %"
    echo "    -h | --help     Print this help and exit"
    echo "    -n | --network  Network CIDR"
    echo "    -f | --file     File name"
    echo "    -t | --tmpfile  File name created by puppet"
    echo ""
    exit 3
}

OPTS=$(getopt -o "h,n:,f:,t:" --longoptions "help,file:,tmpfile:,network:" -- "$@")
eval set -- "$OPTS"

while true; do
    case "$1" in
    -h | --help)
        usage
        ;;
    -n | --network)
        shift
        NETWORK="${1}"
        ;;
    -f | --file)
        shift
        LONG_FILE="${1}"
        SHORT_FILE=$(basename $LONG_FILE)
        ;;
    -t | --tmpfile)
        shift
        TMP_LONG_FILE="${1}"
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

if [[ -z $NETWORK ]]; then
    echo "--network is a mandatory paramter"
    exit 1
elif [[ -z $LONG_FILE ]]; then
    echo "--file is a mandatory paramter"
    exit 1
elif [[ -z $TMP_LONG_FILE ]]; then
    echo "--tmpfile is a mandatory paramter"
    exit 1
fi

if ! jsonlint -q $TMP_LONG_FILE; then
    echo "ERROR validating ${LONG_FILE}"
    exit 1
elif grep -qr --exclude=${SHORT_FILE}* "address.*.${NETWORK}.," /opt/cni/config; then
    echo "ERROR: the network ${NETWORK} is duplicated"
    exit 1
fi