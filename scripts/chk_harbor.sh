#!/bin/bash

### Docker compose File Path Input
DOCKER_COMPOSE_FILE_PATH="/acorn/acornsoft/harbor/install/harbor"

DOCKER_COMPOSE_SERVICE_COUNT=`/usr/bin/docker-compose -f ${DOCKER_COMPOSE_FILE_PATH}/docker-compose.yml ps --services | wc -l`
DOCKER_COMPOSE_SERVICE_FILTER_COUNT=`/usr/bin/docker-compose -f ${DOCKER_COMPOSE_FILE_PATH}/docker-compose.yml ps --services --filter status=running | wc -l`

if [ ${DOCKER_COMPOSE_SERVICE_COUNT} != ${DOCKER_COMPOSE_SERVICE_FILTER_COUNT} ];then
  /usr/bin/docker-compose -f ${DOCKER_COMPOSE_FILE_PATH}/docker-compose.yml down
  /usr/bin/docker-compose -f ${DOCKER_COMPOSE_FILE_PATH}/docker-compose.yml up -d
fi
