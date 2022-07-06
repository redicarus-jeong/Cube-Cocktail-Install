### Incloud ENV File ###
source ./cube_env

CURRENT_PATH=`pwd`

##############################
### Private Container Repo ###
##############################

### runtime
sudo echo "### Container Runtime install ###"
if [ "${OS_TYPE}" == "centos" ]; then
  sudo yum install -y yum-utils device-mapper-persistent-data lvm2
  sudo yum install -y docker-ce

  sudo systemctl enable docker
  sudo systemctl stop docker
  sudo systemctl daemon-reload
  sudo systemctl start docker
  sleep 2

elif [ "${OS_TYPE}" == "ubuntu" ]; then
  if [ ${OS_VERSION} == "1804" ]; then
    echo deb [trusted=true] http://${REPO_URL}/1804dpkg / | sudo tee /etc/apt/sources.list
    sudo apt-get update 2>/dev/null

  elif [ ${OS_VERSION} == "2004" ]; then
    echo deb [trusted=true] http://${REPO_URL}/2004dpkg / | sudo tee /etc/apt/sources.list
    sudo apt-get update 2>/dev/null

  else
    echo "Check Your OS release"
    exit 0
  fi

  echo "It's installing on ${OS_TYPE}"
  sudo apt-get install -y docker.io

  sudo systemctl enable docker
  sudo systemctl stop docker
  sudo systemctl daemon-reload
  sudo systemctl start docker

elif [ "${OS_TYPE}" == "rocky" ];then
  sudo yum install -y yum-utils device-mapper-persistent-data lvm2
  sudo yum install -y docker-ce

  sudo systemctl enable docker
  sudo systemctl stop docker
  sudo systemctl daemon-reload
  sudo systemctl start docker
  sleep 2

else
  echo "Please, Check your OS"
  exit 0
fi

### Harbor Variable define ###
HARBOR_CERT_DIR="${CUBE_TMP}/harbor/certificate"
HARBOR_INSTALL_DIR="${CUBE_TMP}/harbor/install"
HARBOR_RESTORE_DATA_DIR="${CUBE_TMP}/harbor/restore"
HARBOR_LOG_DIR="${CUBE_TMP}/harbor/log"

# Harbor Docker-compose down
sudo rm -rf ${CUBE_TMP}/harbor/install
sudo rm -rf ${CUBE_TMP}/harbor/restore
sudo rm -rf ${CUBE_TMP}/harbor/certificate
sudo rm -rf ${CUBE_WORK}/harbor

### Create Harbor Directroy ###
sudo mkdir -p ${CUBE_TMP}/harbor/certificate
sudo mkdir -p ${CUBE_TMP}/harbor/install
sudo mkdir -p ${CUBE_TMP}/harbor/restore
sudo mkdir -p ${CUBE_TMP}/harbor/log

### Harbor Data Directroy ###
sudo mkdir -p ${CUBE_WORK}/harbor/cert

### Harbor tar job ###
cd ${CURRENT_PATH}
sudo tar xfz harbor-offline-installer-v${CUBE_HARBOR_VERSION}.tgz -C ${HARBOR_INSTALL_DIR}
sudo tar xfzp cube_harbor.tgz -C ${HARBOR_RESTORE_DATA_DIR}

sleep 2

### Harbor Datastore Variable define ###
HARBOR_RESTORE_DIR="${CUBE_WORK}/harbor"

#############################################
### Create Kubernetes OpenSSL Config File ###
#############################################

### Create openssl.conf Create file ###
cat << EOF | sudo tee ${HARBOR_CERT_DIR}/common-openssl.conf
[ req ]
distinguished_name = req_distinguished_name
[req_distinguished_name]

[ v3_ca ]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, keyEncipherment, keyCertSign

[ v3_req_client ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth

[ v3_req_server ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names_registry

[ alt_names_registry ]
DNS.1 = localhost
DNS.2 = ${HOSTNAME}
IP.1 = 127.0.0.1
IP.2 = ${NODE_IP}
EOF

######################################
### Create Front-proxy Certificate ###
######################################
SSLVER=`openssl version | awk {'print $2'}` #openssl 1.1.1 issue
if [ ${SSLVER} =  "1.1.1" ]; then
  sudo openssl rand -out ~/.rnd -hex 256
fi

sudo openssl genrsa -out ${HARBOR_CERT_DIR}/ca.key 2048 && sudo chmod 644 ${HARBOR_CERT_DIR}/ca.key
sudo openssl req -x509 -new -nodes -key ${HARBOR_CERT_DIR}/ca.key -days 3650 -out ${HARBOR_CERT_DIR}/ca.crt -subj '/CN=harbor-ca' -extensions v3_ca -config ${HARBOR_CERT_DIR}/common-openssl.conf
sudo openssl genrsa -out ${HARBOR_CERT_DIR}/harbor.key 2048 && sudo chmod 644 ${HARBOR_CERT_DIR}/harbor.key
sudo openssl req -new -key ${HARBOR_CERT_DIR}/harbor.key -subj '/CN=harbor' | sudo openssl x509 -req -CA ${HARBOR_CERT_DIR}/ca.crt -CAkey ${HARBOR_CERT_DIR}/ca.key -CAcreateserial -out ${HARBOR_CERT_DIR}/harbor.crt -days 3650 -extensions v3_req_server -extfile ${HARBOR_CERT_DIR}/common-openssl.conf


######################################
### Create Front-proxy Certificate ###
######################################

### Create openssl.conf Create file ###
sudo cat << EOF | sudo tee ${HARBOR_INSTALL_DIR}/harbor/harbor.yml
# Configuration file of Harbor

# The IP address or hostname to access admin UI and registry service.
# DO NOT use localhost or 127.0.0.1, because Harbor needs to be accessed by external clients.
hostname: ${NODE_IP}

# http related config
http:
  # port for http, default is 80. If https enabled, this port will redirect to https port
  port: 80

# https related config
https:
  # https port for harbor, default is 443
  port: 443
  # The path of cert and key files for nginx
  certificate: ${HARBOR_CERT_DIR}/harbor.crt
  private_key: ${HARBOR_CERT_DIR}/harbor.key

# Uncomment external_url if you want to enable external proxy
# And when it enabled the hostname will no longer used
# external_url: https://reg.mydomain.com:8433

# The initial password of Harbor admin
# It only works in first time to install harbor
# Remember Change the admin password from UI after launching Harbor.
harbor_admin_password: C0ckt@1lAdmin

# Harbor DB configuration
database:
  # The password for the root user of Harbor DB. Change this before any production use.
  password: root123
  # The maximum number of connections in the idle connection pool. If it <=0, no idle connections are retained.
  max_idle_conns: 50
  # The maximum number of open connections to the database. If it <= 0, then there is no limit on the number of open connections.
  # Note: the default number of connections is 100 for postgres.
  max_open_conns: 100

# The default data volume
data_volume: ${CUBE_WORK}/harbor

# Harbor Storage settings by default is using /data dir on local filesystem
# Uncomment storage_service setting If you want to using external storage
# storage_service:
#   # ca_bundle is the path to the custom root ca certificate, which will be injected into the truststore
#   # of registry's and chart repository's containers.  This is usually needed when the user hosts a internal storage with self signed certificate.
#   ca_bundle:

#   # storage backend, default is filesystem, options include filesystem, azure, gcs, s3, swift and oss
#   # for more info about this configuration please refer https://docs.docker.com/registry/configuration/
#   filesystem:
#     maxthreads: 100
#   # set disable to true when you want to disable registry redirect
#   redirect:
#     disabled: false

# Clair configuration
clair:
  # The interval of clair updaters, the unit is hour, set to 0 to disable the updaters.
  updaters_interval: 12

jobservice:
  # Maximum number of job workers in job service
  max_job_workers: 10

notification:
  # Maximum retry count for webhook job
  webhook_job_max_retry: 10

chart:
  # Change the value of absolute_url to enabled can enable absolute url in chart
  absolute_url: disabled

# Log configurations
log:
  # options are debug, info, warning, error, fatal
  level: info
  # configs for logs in local storage
  local:
    # Log files are rotated log_rotate_count times before being removed. If count is 0, old versions are removed rather than rotated.
    rotate_count: 50
    # Log files are rotated only if they grow bigger than log_rotate_size bytes. If size is followed by k, the size is assumed to be in kilobytes.
    # If the M is used, the size is in megabytes, and if G is used, the size is in gigabytes. So size 100, size 100k, size 100M and size 100G
    # are all valid.
    rotate_size: 200M
    # The directory on your host that store log
    location: /var/log/harbor

  # Uncomment following lines to enable external syslog endpoint.
  # external_endpoint:
  #   # protocol used to transmit log to external endpoint, options is tcp or udp
  #   protocol: tcp
  #   # The host of external endpoint
  #   host: localhost
  #   # Port of external endpoint
  #   port: 5140

#This attribute is for migrator to detect the version of the .cfg file, DO NOT MODIFY!
_version: 1.10.0

# Uncomment external_database if using external database.
# external_database:
#   harbor:
#     host: harbor_db_host
#     port: harbor_db_port
#     db_name: harbor_db_name
#     username: harbor_db_username
#     password: harbor_db_password
#     ssl_mode: disable
#     max_idle_conns: 2
#     max_open_conns: 0
#   clair:
#     host: clair_db_host
#     port: clair_db_port
#     db_name: clair_db_name
#     username: clair_db_username
#     password: clair_db_password
#     ssl_mode: disable
#   notary_signer:
#     host: notary_signer_db_host
#     port: notary_signer_db_port
#     db_name: notary_signer_db_name
#     username: notary_signer_db_username
#     password: notary_signer_db_password
#     ssl_mode: disable
#   notary_server:
#     host: notary_server_db_host
#     port: notary_server_db_port
#     db_name: notary_server_db_name
#     username: notary_server_db_username
#     password: notary_server_db_password
#     ssl_mode: disable

# Uncomment external_redis if using external Redis server
# external_redis:
#   host: redis
#   port: 6379
#   password:
#   # db_index 0 is for core, it's unchangeable
#   registry_db_index: 1
#   jobservice_db_index: 2
#   chartmuseum_db_index: 3
#   clair_db_index: 4

# Uncomment uaa for trusting the certificate of uaa instance that is hosted via self-signed cert.
# uaa:
#   ca_file: /path/to/ca

# Global proxy
# Config http proxy for components, e.g. http://my.proxy.com:3128
# Components doesn't need to connect to each others via http proxy.
# Remove component from `components` array if want disable proxy
# for it. If you want use proxy for replication, MUST enable proxy
# for core and jobservice, and set `http_proxy` and `https_proxy`.
# Add domain to the `no_proxy` field, when you want disable proxy
# for some special registry.
proxy:
  http_proxy:
  https_proxy:
  # no_proxy endpoints will appended to 127.0.0.1,localhost,.local,.internal,log,db,redis,nginx,core,portal,postgresql,jobservice,registry,registryctl,clair,chartmuseum,notary-server
  no_proxy:
  components:
    - core
    - jobservice
    - clair
EOF

### Harbor Base Install ###
sudo ${HARBOR_INSTALL_DIR}/harbor/install.sh --with-clair --with-chartmuseum |sudo tee ${HARBOR_LOG_DIR}/harbor-install.log

# Harbor Docker-compose down
sudo docker-compose -f ${HARBOR_INSTALL_DIR}/harbor/docker-compose.yml down

# Database Task harbor-db container Docker run
sudo docker run -d --name harbor-db -v ${HARBOR_RESTORE_DATA_DIR}/harbor:/backup -v ${CUBE_WORK}/harbor/database:/var/lib/postgresql/data goharbor/harbor-db:v${CUBE_HARBOR_VERSION} "postgres"

### Harbor Status Check ###
sudo docker exec harbor-db pg_isready | grep "accepting connections"
sleep 10

### Harbor Restore execute ###
# Harbor db drop
echo "### CUBE Harbor db drop ###"
sudo docker exec harbor-db psql -U postgres -d template1 -c "drop database registry;"
sudo docker exec harbor-db psql -U postgres -d template1 -c "drop database postgres;"
sudo docker exec harbor-db psql -U postgres -d template1 -c "drop database notarysigner; "
sudo docker exec harbor-db psql -U postgres -d template1 -c "drop database notaryserver;"

# Harbor db create
echo "### Harbor db create ###"
sudo docker exec harbor-db psql -U postgres -d template1 -c "create database registry;"
sudo docker exec harbor-db psql -U postgres -d template1 -c "create database postgres;"
sudo docker exec harbor-db psql -U postgres -d template1 -c "create database notarysigner;"
sudo docker exec harbor-db psql -U postgres -d template1 -c "create database notaryserver;"

# Harbor restore database copy
echo "### Harbor restore database copy ###"
sudo docker cp ${HARBOR_RESTORE_DATA_DIR}/harbor/db/registry.back harbor-db:/tmp/registry.back
sudo docker cp ${HARBOR_RESTORE_DATA_DIR}/harbor/db/postgres.back harbor-db:/tmp/postgres.back
sudo docker cp ${HARBOR_RESTORE_DATA_DIR}/harbor/db/notarysigner.back harbor-db:/tmp/notarysigner.back
sudo docker cp ${HARBOR_RESTORE_DATA_DIR}/harbor/db/notaryserver.back harbor-db:/tmp/notaryserver.back

# Harbor Database Restore Execute
echo "### Harbor Database Restore Execute ###"
sudo docker exec harbor-db sh -c 'psql -U postgres registry < /tmp/registry.back'
sudo docker exec harbor-db sh -c 'psql -U postgres postgres < /tmp/postgres.back'
sudo docker exec harbor-db sh -c 'psql -U postgres notarysigner < /tmp/notarysigner.back'
sudo docker exec harbor-db sh -c 'psql -U postgres notaryserver < /tmp/notaryserver.back'

sudo docker exec harbor-db sh -c "psql -U postgres registry -c \"update properties set v='https://${NODE_IP}' where k='ext_endpoint'\""

# Database Task harbor-db container Docker stop, rm
sudo docker stop harbor-db
sudo docker rm harbor-db

# Harbor registry Copy
echo "### Harbor registry Copy ###"
sudo cp -rf ${HARBOR_RESTORE_DATA_DIR}/harbor/registry/* ${CUBE_WORK}/harbor/registry

# Harbor Chart_stroage Copyh
sudo cp -rf ${HARBOR_RESTORE_DATA_DIR}//harbor/chart_storage/* ${CUBE_WORK}/harbor/chart_storage

# Harbor Secret Copy
sudo cp -R ${HARBOR_RESTORE_DATA_DIR}/harbor/secret ${CUBE_WORK}/harbor/

### harbor Certificate ca.crt Copy nginx
sudo mkdir -p ${HARBOR_INSTALL_DIR}/harbor/common/config/nginx/cert/
sudo cp ${HARBOR_CERT_DIR}/ca.crt ${HARBOR_INSTALL_DIR}/harbor/common/config/nginx/cert/ca.crt

NGINX_CONFIG_CHECK=`sudo ls ${HARBOR_INSTALL_DIR}/harbor/common/config/nginx/nginx.conf_origin 2>/dev/null`

if [ -z ${NGINX_CONFIG_CHECK} ]; then
  echo "Not Found Harbor Origin config backup file"
  echo "Next Task Progress"
else
  echo "Found Harbor config backup file"
  echo "Nginx File Origin restore"
  sudo rm -rf ${HARBOR_INSTALL_DIR}/harbor/common/config/nginx/nginx.conf
  sudo mv ${HARBOR_INSTALL_DIR}/harbor/common/config/nginx/nginx.conf_origin ${HARBOR_INSTALL_DIR}/harbor/common/config/nginx/nginx.conf
fi

sudo cp -ap ${HARBOR_INSTALL_DIR}/harbor/common/config/nginx/nginx.conf ${HARBOR_INSTALL_DIR}/harbor/common/config/nginx/nginx.conf_origin

CH_LINE=`sudo cat ${HARBOR_INSTALL_DIR}/harbor/common/config/nginx/nginx.conf | grep chunked_transfer_encoding -n | awk -F ':' '{print $1}'`
CH_LINE=`expr $CH_LINE + 1`
sudo awk 'NR=='"$CH_LINE"'{print "    location /ca.crt {"}1' ${HARBOR_INSTALL_DIR}/harbor/common/config/nginx/nginx.conf | sudo tee ${CUBE_EXEC}/cube/temp/out_01
CH_LINE=`expr $CH_LINE + 1`
sudo awk 'NR=='"$CH_LINE"'{print "      alias /etc/nginx/cert/ca.crt;"}1' ${CUBE_EXEC}/cube/temp/out_01 | sudo tee ${CUBE_EXEC}/cube/temp/out_02 1>/dev/null
CH_LINE=`expr $CH_LINE + 1`
sudo awk 'NR=='"$CH_LINE"'{print "    }"}1' ${CUBE_EXEC}/cube/temp/out_02 | sudo tee ${CUBE_EXEC}/cube/temp/out_03 1>/dev/null

sudo cat < ${CUBE_EXEC}/cube/temp/out_03 | sudo tee ${HARBOR_INSTALL_DIR}/harbor/common/config/nginx/nginx.conf

sudo rm -rf ${CUBE_EXEC}/cube/temp/out_*

# Harbor up
sudo chown -R 10000.10000 ${HARBOR_RESTORE_DIR}/registry/docker
sudo docker-compose -f ${HARBOR_INSTALL_DIR}/harbor/docker-compose.yml up -d
