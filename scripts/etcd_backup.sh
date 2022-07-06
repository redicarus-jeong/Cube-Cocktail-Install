#!/bin/sh

# usage: cocktail-backup-light.sh save_path days
# etcd_backup.sh /nas/BACKUP/ 7

export ETCDCTL_API=3
NODE_IP=`ip addr | grep global | grep -E -v "docker|br-|tun" | awk '{print $2}' | cut -d/ -f1`

ETCD_CERT="/etc/kubernetes/pki/etcd/peer.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/peer.key"
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"

ETCD_EP=${NODE_IP}
CURRENT_DATE=`date '+%Y%m%d'`
CURRENT_TIME=`date '+%Y%m%d_%H%M%S'`

ETCD_BACKDIR="$1"


error_exit() {
    echo "error: ${1:-"unknown error"}" 1>&2
    exit 1
}

main() {
    if [ "$#" -ne 2 ]; then
        echo "./cocktail-backup-light.sh /nas/BACKUP/ 10"
        error_exit "Illegal number of parameters. You must pass backup directory path and number of days to keep backups"
    fi


    echo "Getting ready to backup to etcd(${ETCD_BACKDIR})"
    /usr/bin/etcdctl --cert "${ETCD_CERT}" --key "${ETCD_KEY}" --cacert "${ETCD_CACERT}" --endpoints="${ETCD_EP}" snapshot save "${ETCD_BACKDIR}/etcd_${CURRENT_TIME}"
    sudo find ${COCKTAIL_BACKDIR} -name "etcd*" -mtime +$2 | xargs rm -rf
    find /acorn/backup-logs/etcd/ -name "*" -mtime +30 | xargs rm -rf
    echo "Backup completed."
}

main "${@:-}"
