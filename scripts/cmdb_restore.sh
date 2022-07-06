#!/bin/sh

# usage: cocktail_backup.sh save_path days
# ./cocktail-backup.sh /nas/BACKUP/filename

export KUBECONFIG=/etc/kubernetes/admin.conf

COCKTAIL_RESTORE="$1"
COCKTAIL_NS=cocktail-system
COCKTAIL_POD_RESTORE="acloud_cmdb_dump.sql.gz"

error_exit() {
    echo "error: ${1:-"unknown error"}" 1>&2
    exit 1
}

verify_prereqs() {
    echo "Verifying Prerequisites"

    if [ ! -f $COCKTAIL_RESTORE ]; then
        error_exit "Can't access cmdb backup file $COCKTAIL_RESTORE"
    fi

    chk_cmdb=`kubectl get sts -n $COCKTAIL_NS | grep api-cmdb | wc -l`

    if [ "${chk_cmdb}" -eq 1 ]; then
        acloud_cmdb_pod=`kubectl get pods -n $COCKTAIL_NS | grep cocktail-api-cmdb-0 | awk '{print $1}'`
        sqlrestorecmd='/usr/bin/mysql'
    else
        acloud_cmdb_pod=`kubectl get pods -n $COCKTAIL_NS | grep api-cmdb | awk '{print $1}'`
        sqlrestorecmd='/usr/bin/mysql'
    fi

        if [ -z $acloud_cmdb_pod ]; then
                echo "Can't get acloud cmdb pod name. exit."
                exit 1;
        fi
}

main() {
    if [ "$#" -ne 1 ]; then
        echo "./cocktail-restore.sh /nas/BACKUP/filename"
        error_exit "Illegal number of parameters. You must pass restore directory path"
    fi

    verify_prereqs

    echo "Getting ready to restore to cmdb($COCKTAIL_RESTORE)"
    sudo kubectl cp $COCKTAIL_RESTORE $COCKTAIL_NS/$acloud_cmdb_pod:/tmp/$COCKTAIL_POD_RESTORE
    kubectl exec "$acloud_cmdb_pod" -n $COCKTAIL_NS -- sh -c "gunzip < /tmp/$COCKTAIL_POD_RESTORE | ${sqlrestorecmd} -u root -pC0ckt@ilWks@2"
    
    #kubectl exec -n $COCKTAIL_NS $acloud_cmdb_pod -- sh -c "rm /tmp/*.gz"

    echo "Restore completed."
}

main "${@}"