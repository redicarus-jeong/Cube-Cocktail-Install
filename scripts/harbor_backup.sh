#!/bin/bash

CURRENT_DATE=`date '+%Y%m%d'`
CURRENT_TIME=`date '+%Y%m%d_%H%M%S'`

#BACKUP_DIR="/root/backup/harbor_backup"
BACKUP_DIR="/backup"
HARBOR_DIR="/acorn/harbor"

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
    cp -rfp ${HARBOR_DIR}/registry  ${BACKUP_DIR}/harbor/
}

backup_chart_museum() {
    if [ -d ${HARBOR_DIR}/chart_storage ]; then
        cp -rfp ${HARBOR_DIR}/chart_storage ${BACKUP_DIR}/harbor/
    fi
}

backup_secret() {
    if [ -f ${HARBOR_DIR}/secretkey ]; then
        cp ${HARBOR_DIR}/secretkey ${BACKUP_DIR}/harbor/secret/
    fi
    if [ -f ${HARBOR_DIR}/defaultalias ]; then
         cp -rfp ${HARBOR_DIR}/defaultalias ${BACKUP_DIR}/harbor/secret/
    fi
    # location changed after 1.8.0
    if [ -d ${HARBOR_DIR}/secret/keys/ ]; then
        cp -rfp ${HARBOR_DIR}/secret/keys/ ${BACKUP_DIR}/harbor/secret/
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

