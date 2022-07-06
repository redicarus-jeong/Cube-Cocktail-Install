[BACKUP]

Cocktail Cloud Backup / Restore (CUBE 구현 예정)

```

[이미지 저장소 관련 스크립트]
harbor_backup.sh
 - Private Container images (Harbor Backup / Harbor Restore)
 - Private Helm (Harbor Backup / Harbor Restore)

[CMDB Backup / Restore 스크립트]
cmdb_backup.sh
 - Cocktail Cloud 의 CMDB 를 백업
cmdb_restore.sh
 - Cocktail Cloud 의 CMDB 에 백업된 SQL 파일을 통한 복원

[운영중인 상태체크 스크립트]
chk_harbor.sh
 - harbor 의 service list 를 추출하고, harbor 의 running 중인 service 갯수를 확인하여 정상여부판단
etcd_check.sh
 - etcd 의 pid 값이 존제하는지 아는지 여부로 etcd 의 상태를 확인


추가작업 해야할것들 내용정리
3. Private Package (RPM File Backup / Restore)
4. Cocktail Cloud 운영 Data (CMDB[Mysql] Backup / Restore)
5. Cocktail Cloud 모니터링 Data (PostgreSQL Backup / Restore)
6. Kubernetes Data (ETCD Snapshot Backup / Restore)
7. Kubernetes Config (kubernetes Config File Backup / Restore)
8. Cube Data (Install tar file)
9. Cube Config (cube_env, kubeadm.yaml, calico.yaml)
 - cube_env (설치환경파일)
 - kubeadm.yaml (kubeadm 설치환경파일)
 - Calico.yaml (CNI 설치파일)
 - openssl.conf (인증서 환경설정 파일)
 - 각종 인증서 파일 (kubernetes, etcd, harbor)
 - kubernetes config 파일 (kubernetes 용 각종 kubeconfig)
 - Runc config 파일 (Containerd config.toml)
10. Cocktail Cloud 운영 Scripts (Cronjob)

```



### [SAMPLE Scripts]

```

[ETCD Backup]
# etcd backup
/bin/etcdctl --endpoints="$ETCD_EP" snapshot save "$BACKDIR/compressed/etcd_$CURRENT_TIME"
cp -f /etc/etcd/etcd.conf $BACKDIR/compressed
cp -f /etc/systemd/system/etcd.service $BACKDIR/compressed



[Cluster Config Backup]
# cluster config backup
cp -rf /etc/kubernetes $BACKDIR/compressed
cp -rf /opt/kubernetes $BACKDIR/compressed/system
cp /etc/sysconfig/kubelet $BACKDIR/compressed/system/etc_sysconfig_kubelet
cp /var/lib/kubelet/config.yaml $BACKDIR/compressed/system/var_lib_kubelet_config.yaml
cp /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf $BACKDIR/compressed/system
cd $BACKDIR
tar -zcf $BACKDIR/cluster_$CURRENT_TIME.tar.gz compressed
find $BACKDIR -name "cluster*" -mtime +`expr $2 - 1` | xargs rm -rf
rm -rf $BACKDIR/compressed
echo "Backup completed."



[CMDB Backup]
verify_prereqs() {
    echo "Verifying Prerequisites"

    if [ ! -d $COCKTAIL_BACKDIR ]; then
        error_exit "Can't access cmdb backup directory $ETCD_BACKDIR"
    fi

    chk_cmdb=`kubectl get sts -n $COCKTAIL_NS | grep api-cmdb | wc -l`

    if [ "${chk_cmdb}" -eq 1 ]; then
        acloud_cmdb_pod=`kubectl get pods -n $COCKTAIL_NS | grep api-cmdb-cocktail-0 | awk '{print $1}'`
        sqldumpcmd='/opt/bitnami/mariadb/bin/mysqldump'
    else
        acloud_cmdb_pod=`kubectl get pods -n $COCKTAIL_NS | grep api-cmdb | awk '{print $1}'`
        sqldumpcmd='/usr/bin/mysqldump'
    fi

	if [ -z $acloud_cmdb_pod ]; then
		echo "Can't get acloud cmdb pod name. exit."
		exit 1;
	fi
}

main() {
    if [ "$#" -ne 2 ]; then
		echo "./cocktail-backup.sh /nas/BACKUP/ 10"
        error_exit "Illegal number of parameters. You must pass backup directory path and number of days to keep backups"
    fi

    verify_prereqs

    echo "Getting ready to backup to  cmdb($COCKTAIL_BACKDIR)"

    db_passwd=`kubectl get secret cocktail-secret -o jsonpath="{.data.COCKTAIL_DB_PASSWORD}" -n $COCKTAIL_NS | base64 -d`

    kubectl exec "$acloud_cmdb_pod" -n $COCKTAIL_NS -- sh -c "${sqldumpcmd} --single-transaction --databases acloud builder -u root -p${db_passwd} > /tmp/acloud_cmdb_dump.$CURRENT_TIME.sql"
    kubectl cp $COCKTAIL_NS/$acloud_cmdb_pod:/tmp/acloud_cmdb_dump.$CURRENT_TIME.sql $COCKTAIL_BACKDIR/acloud_cmdb_dump.$CURRENT_TIME.sql
    kubectl exec -n $COCKTAIL_NS $acloud_cmdb_pod -- sh -c "rm /tmp/acloud_cmdb_dump.$CURRENT_TIME.sql"

	gzip $COCKTAIL_BACKDIR/acloud_cmdb_dump.$CURRENT_TIME.sql

	find $COCKTAIL_BACKDIR -name "*cmdb_dump*" -mtime +`expr $2 - 1` | xargs rm -rf
    echo "Backup completed."


[Harbor Backup]

#!/bin/bash

CURRENT_DATE=`date '+%Y%m%d'`
CURRENT_TIME=`date '+%Y%m%d_%H%M%S'`

BACKUP_DIR="/root/backup/harbor_backup"
HARBOR_DIR="/data/harbor"

error_exit() {
    echo "error: ${1:-"unknown error"}" 1>&2
    exit 1
}

create_dir(){
    rm -rf ${BACKUP_DIR}/harbor
    mkdir -p ${BACKUP_DIR}/harbor/db
    mkdir -p ${BACKUP_DIR}/harbor/secret
    chmod 777 ${BACKUP_DIR}/harbor/db
    chmod 777 ${BACKUP_DIR}/harbor/secret
}

dump_database() {
    $DOCKER_CMD exec harbor-db sh -c 'pg_dump -U postgres registry ' > ${BACKUP_DIR}/harbor/db/registry.back
    $DOCKER_CMD exec harbor-db sh -c 'pg_dump -U postgres postgres ' > ${BACKUP_DIR}/harbor/db/postgres.back
    $DOCKER_CMD exec harbor-db sh -c 'pg_dump -U postgres notarysigner ' > ${BACKUP_DIR}/harbor/db/notarysigner.back
    $DOCKER_CMD exec harbor-db sh -c 'pg_dump -U postgres notaryserver ' > ${BACKUP_DIR}/harbor/db/notaryserver.back
}

backup_registry() {
    cp -rf ${HARBOR_DIR}/registry  ${BACKUP_DIR}/harbor/
}

backup_chart_museum() {
    if [ -d ${HARBOR_DIR}/chart_storage ]; then
        cp -rf ${HARBOR_DIR}/chart_storage ${BACKUP_DIR}/harbor/
    fi
}

backup_secret() {
    if [ -f ${HARBOR_DIR}/secretkey ]; then
        cp ${HARBOR_DIR}/secretkey ${BACKUP_DIR}/harbor/secret/
    fi
    if [ -f ${HARBOR_DIR}/defaultalias ]; then
         cp ${HARBOR_DIR}/defaultalias ${BACKUP_DIR}/harbor/secret/
    fi
    # location changed after 1.8.0
    if [ -d ${HARBOR_DIR}/secret/keys/ ]; then
        cp -r ${HARBOR_DIR}/secret/keys/ ${BACKUP_DIR}/harbor/secret/
    fi
}

create_tarball() {
 	cd ${BACKUP_DIR}
    tar zcvf ${BACKUP_DIR}/harbor.$CURRENT_TIME.tgz harbor
    rm -rf ${BACKUP_DIR}/harbor
}

main() {

    set -ex

    DOCKER_CMD=docker
    harbor_db_image=$($DOCKER_CMD images goharbor/harbor-db --format "{{.Repository}}:{{.Tag}}" | head -1)
    harbor_db_path="${HARBOR_DIR}/database"

    create_dir
    dump_database
    backup_registry
    backup_chart_museum
    backup_secret
    create_tarball

    echo "All Harbor data are backed up"
}

main "${@}"

```