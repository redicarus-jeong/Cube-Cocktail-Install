#!/usr/bin/env bash

### This script is only Cube Harbor Private Registry Setup Script on CentOS-7.9 
### This script has been separated from the cube-5.2.3 installation script that name is 92_private_harbor.sh.
### This script needs to be run from the directory with files cube_harbor.tgz and harbor-offline-installer-v1.10.6.tgz.
### Modified Date : 2022-06-08
### Author : redicarus.jeong

CurrentPath=$(pwd)
IFName="enp0s8"
IF_IPADDRESS=$(ip addr show dev ${IFName} scope global |grep inet|awk '{print $2}'|cut -d'/' -f1)

### Veriable define
#RepositoryHostname="repository"
RepositoryHostname="repoharbornfs"
RepositoryName="CentOS-7.9_RPMRepo"
BaseRepositoryDirectory="/PrivateRepo"
DockerUser="cocktail bluesky"
NetworkType="private"
GPUNode="disable"
RepoPort=3777

### harbor Variable define
HarborVersion="1.10.6"
CubeVersion="1.21"
MainDir="/APP"
CubeWork="${MainDir}/acorn"
CubeDir="${CubeWork}/cube"
CubeData="${CubeWork}/data"
CubeTmp="${MainDir}/acornsoft"
CubeExec="${MainDir}/cocktail"
AWSServer="disable"

HarborCertPeriod=3650
HarborMainDir="${CubeTmp}/harbor"
HarborCertificateDir="${CubeTmp}/harbor/certificate"
HarborInstallDir="${CubeTmp}/harbor/install"
HarborRestoreDataDir="${CubeTmp}/harbor/restore"
HarborLogDir="${CubeTmp}/harbor/log"
HarborDataStoreDir="${CubeWork}/harbor"
HarborCertDir="${CubeWork}/harbor/cert"

HarborDirList=("install" "restore" "certificate" "log")
HarborTarFileList=("cube_harbor.tgz" "harbor-offline-installer-v1.10.6.tgz" "cube_bin-etcd.tar.gz")

HarborInstallConfFile=${HarborInstallDir}/harbor/harbor.yml
HarborAdminPassword='C0ckt@1lAdmin'

##############################################################################################################
##### 1. cube-harbor & harbot-install tar.gz file check in current dir
echo "===> 1. cube-harbor & harbot-install tar.gz file check in current dir" 
echo "#######################################################################################################"
TarFileCount=0
for TarFileName in ${HarborTarFileList[@]} 
    do
        if [ -f ${CurrentPath}/${TarFileName} ]; then
            TarFileCount=$(expr $TarFileCount + 1 )
        else
            echo ">>>> Not Found $TarFileName in current directory"
        fi
done
if [ ${TarFileCount} -ne 3 ]; then
    echo ">>>> Not enough tar file. three tar files are required. please check tar fil."
    echo ">>>> 1) cube_harbor.tgz"
    echo ">>>> 2) harbor-offline-installer-v1.10.6.tgz"
    echo ">>>> 3) cube_bin-etcd.tar.gz"
    exit 1
fi

OS_TYPE=`grep ^NAME /etc/os-release | grep -oP '"\K[^"]+' | awk '{print $1}' | tr '[:upper:]' '[:lower:]'`
OS_VERSION=`cat /etc/centos-release | awk {'print $4'} | awk -F "." {'print $1 "." $2'}`

### AWS Check "enable" or "disable"
if [ "${OS_TYPE}" = "centos" ]; then
    AWS_SERVER=disable
elif [ "${OS_TYPE}" = "amazon" ]; then
    AWS_SERVER=enable
else
    echo; echo ">>>> Check the OS Type! This Script can be run on centos or amazon."; echo
    exit 1
fi
echo
echo ">>>> OS Type = ${OS_TYPE}"
echo ">>>> OS Version = ${OS_VERSION}"
echo ">>>> AWS Server = ${AWS_SERVER}"
echo


### 2. CentOS & Cube Private Repository Check & Connect 
echo "===> 2. CentOS & Cube Private Repository Connect"
echo "#######################################################################################################"
### 2-1. yum.repos.d backup
echo "---> 2-1. yum.repos.d backup"
if [ -d /etc/yum.repos.d.backup ]; then
    sudo mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d.backup/
else
    sudo mv -f /etc/yum.repos.d /etc/yum.repos.d.backup
    sudo mkdir -p /etc/yum.repos.d
    sudo chown root:root /etc/yum.repos.d
    sudo chmod 0755 /etc/yum.repos.d
fi

### 2-2. Private Repository repo file create or modify in yum.repos.d
##### --> need modify : if local pkg repository
echo "---> 2-2. Private Repository repo file create or modify in yum.repos.d"

function yumrepo_modify() {
cat << EOF | sudo tee /etc/yum.repos.d/79rpm.repo
[CentOS-7.9_Private_Repository]
name=CentOS-7.9 Everthing and Cube rpm repository
baseurl=http://$1:$2
gpgcheck=0
enabled=1
EOF
}

RepositoryIP=$(grep ${RepositoryHostname} /etc/hosts | awk 'NR==1 {print $1}')
RepoPingCount=$(ping -c 3 ${RepositoryIP} | grep received |cut -d',' -f2|awk '{print $1}' | sed 's/ //g')
if [  $RepoPingCount -ne 3 ]; then
    echo ">>>> Check CentOS-7.9 Private RPM Repository Server IP"
    exit 1
else
    echo ">>>> CentOS-7.9 Private RPM Repository Server IP = ${RepositoryIP}"
    if [ ! -f /etc/yum.repos.d/79rpm.repo ]; then
        echo ">>>> Not found 79rpm.repo file in /etc/yum.repos.d "
        echo ">>>> Proceed with 79rpm repository connect."
        ##### function is yumrepo_modify call 
        yumrepo_modify ${RepositoryIP} ${RepoPort}
    else
        PKGRepoBaseURL=$(grep baseurl /etc/yum.repos.d/79rpm.repo | cut -d':' -f1 | cut -d'=' -f2 ) 
        if [ "${PKGRepoBaseURL}" = "file" ];then
            echo ">>>> This VM(Server) is CentOS PKG9rpm) Repositiry"
        fi
        echo "-------------------------------------------"
        sudo cat /etc/yum.repos.d/79rpm.repo
        echo "-------------------------------------------"    
    fi
    sudo yum clean all
    sudo yum repolist all
fi    


### 3. Firewalld disable
echo "===> 3. firewalld disable"
echo "#######################################################################################################"
IsActive=$(systemctl is-active firewalld)
IsEnable=$(systemctl is-enabled firewalld)
if [ "${IsActive}" = "active" ]; then
    sudo systemctl stop firewalld
fi
if [ "${IsEnable}" = "enabled" ]; then
    sudo systemctl disable firewalld
fi


### 4. Selinux permissive (disable)
echo "===> 4. Selinux mode change to permissive"
echo "#######################################################################################################"
#SeLinuxIsEnable=$(sestatus | grep ^"SELinux status:" | cut -d':' -f2 | sed 's/ //g')
#SeLinuxMode=$(sestatus | grep ^"Current mode:" | cut -d':' -f2 | sed 's/ //g')              # enforcing / permissive / disabled
SeLinuxInFileMode=$(grep ^'SELINUX=' /etc/selinux/config | cut -d'=' -f2)
sudo setenforce 0
if [ "${SeLinuxInFileMode}" = "enforcing" ]; then
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
fi


### 5. Container Runtime Install
echo "===> 5. Container Runtime(docker-ce) Install"
echo "#######################################################################################################"
sudo yum reinstall -y yum-utils device-mapper-persistent-data lvm2
sudo yum install -y docker-ce
if [ $? -eq 0 ]; then
    sudo systemctl enable docker
    sudo systemctl stop docker
    sudo systemctl daemon-reload
    sudo systemctl start docker
    IsActive=$(systemctl is-active docker)
    if [ "${IsActive}" = "unknown" ]; then
        echo ">>>> Check docker daemon : ${IsActive}"
        exit 1
    fi
    sudo systemctl status docker
    sudo docker version
else
    echo ">>>> Docker Runtime(docker-ce) Install Failed"
    exit 1
fi


### 6. create harbor & cube directory
### HarborDirList=("install" "restore" "certificate" "log")
echo "===> 6. create harbor & cube directory"
echo "#######################################################################################################"
##### 6-1. create harbor directory 
echo "===> 6-1. create harbor directory"
for DirName in ${HarborDirList[@]}
    do
        if [ -d ${HarborMainDir}/${DirName} ]; then
            sudo rm -r ${HarborMainDir}/${DirName}
        fi
        sudo mkdir -p ${HarborMainDir}/${DirName}
        echo ">>>> Create harbor directory = ${HarborMainDir}/${DirName}"
done
if [ -d ${HarborCertDir} ]; then
    sudo rm -r ${HarborCertDir}
fi
sudo mkdir -p ${HarborCertDir}

##### 6-2. create cube directory 
echo "===> 6-2. create cube directory "
if [ -d ${CubeDir}/temp ]; then
    sudo rm -r ${CubeDir}/temp
fi
sudo mkdir -p ${CubeDir}/temp


### 7. harbor & cube binary tar file extract & cube binary file copy / link
### HarborTarFileList=("cube_harbor.tgz" "harbor-offline-installer-v1.10.6.tgz" "cube_bin-etcd.tar.gz")
echo "===> 7. harbor & cube binary tar file extract & cube binary file copy / link"
echo "#######################################################################################################"
for tarfile in ${HarborTarFileList[@]}
    do
        if [ -f ${CurrentPath}/${tarfile} ]; then
            if [ "${tarfile}" = "cube_harbor.tgz" ]; then
                echo ">>>> ${tarfile} extract in ${HarborRestoreDataDir}"
                sudo tar xzfp ${CurrentPath}/${tarfile} -C ${HarborRestoreDataDir}
            fi
            if [ "${tarfile}" = "harbor-offline-installer-v1.10.6.tgz" ]; then
                echo ">>>> ${tarfile} extract in ${HarborInstallDir}"
                sudo tar xzf ${CurrentPath}/${tarfile} -C ${HarborInstallDir}
            fi
            if [ "${tarfile}" = "cube_bin-etcd.tar.gz" ]; then
                sudo tar xzf ${CurrentPath}/${tarfile} -C ${CubeDir}
                BinaryFiles=("docker-compose" "helm" "sshpass")
                for binfile in ${BinaryFiles[@]}
                    do
                        if [ -f ${CubeDir}/binary/${binfile} ]; then
                            sudo cp -ap ${CubeDir}/binary/${binfile} /usr/local/bin/
                            sudo chown root:root /usr/local/bin/${binfile}
                            sudo ln -sf /usr/local/bin/${binfile} /usr/bin/${binfile}
                            echo ">>>> cube ${binfile} copy & link(ln) Success"
                        else
                            echo ">>>> cube ${binfile} copy & link(ln) Failed"
                            exit 1
                        fi
                done
           fi
        else
            echo ">>>> Not Found ${tarfile} in ${CurrentPath}"
            exit 1
        fi
done


### 8. Create openssl.conf Create file ###
echo "===> 8. Create openssl.conf Create file in $HarborCertificateDir"
echo "#######################################################################################################"
cat << EOF | sudo tee ${HarborCertificateDir}/common-openssl.conf
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
IP.2 = ${IF_IPADDRESS}
EOF


### 9. Create Front-proxy Certificate ###
echo "===> 9. Create Front-proxy Certificate"
echo "#######################################################################################################"
SSLVER=$(openssl version | awk {'print $2'}) #openssl 1.1.1 issue
if [ ${SSLVER} =  "1.1.1" ]; then
  sudo openssl rand -out ~/.rnd -hex 256
fi

if [ -d ${HarborCertificateDir} ]; then
    ##### 9-1. General RSA Key Gen #####
    echo "---> 9-1. General RSA Key Gen "
    sudo openssl genrsa \
         -out ${HarborCertificateDir}/ca.key 2048 \
         && sudo chmod 644 ${HarborCertificateDir}/ca.key
    if [ -f  ${HarborCertificateDir}/ca.key ]; then
        echo ">>>> RSA Key Generation Success : ${HarborCertificateDir}/ca.key"
    else 
        echo ">>>> RSA Key Generation Failed : ${HarborCertificateDir}/ca.key"
        exit 1
    fi

    ##### 9-2. General Request Gen #####
    echo "---> 9-2. General Request Gen "
    sudo openssl req \
         -x509 \
         -new \
         -nodes \
         -key ${HarborCertificateDir}/ca.key \
         -days ${HarborCertPeriod} \
         -out ${HarborCertificateDir}/ca.crt \
         -subj '/CN=harbor-ca' \
         -extensions v3_ca \
         -config ${HarborCertificateDir}/common-openssl.conf
    if [ -f  ${HarborCertificateDir}/ca.crt ]; then
        echo ">>>> Request Generation Success : ${HarborCertificateDir}/ca.crt"
    else 
        echo ">>>> Request Generation Failed : ${HarborCertificateDir}/ca.crt"
        exit 1
    fi

    ##### 9-3. Harbor RSA Key Gen #####
    echo "---> 9-3. Harbor RSA Key Gen "
    sudo openssl genrsa \
         -out ${HarborCertificateDir}/harbor.key 2048 \
         && sudo chmod 644 ${HarborCertificateDir}/harbor.key
    if [ -f  ${HarborCertificateDir}/harbor.key ]; then
        echo ">>>> Request Generation Success : ${HarborCertificateDir}/harbor.key"
    else 
        echo ">>>> Request Generation Failed : ${HarborCertificateDir}/harbor.key"
        exit 1
    fi
    
    ##### 9-4. Harbor Request Gen #####
    echo "---> 9-4. Harbor Request Gen "
    sudo openssl req \
         -new \
         -key ${HarborCertificateDir}/harbor.key \
         -subj '/CN=harbor' | \
         sudo openssl x509 -req \
              -CA ${HarborCertificateDir}/ca.crt \
              -CAkey ${HarborCertificateDir}/ca.key \
              -CAcreateserial \
              -out ${HarborCertificateDir}/harbor.crt \
              -days ${HarborCertPeriod} \
              -extensions v3_req_server \
              -extfile ${HarborCertificateDir}/common-openssl.conf
    if [ -f  ${HarborCertificateDir}/harbor.crt ]; then
        echo ">>>> Harbor Request Generation Success : ${HarborCertificateDir}/harbor.crt"
    else 
        echo ">>>> Harbor Request Generation Failed : ${HarborCertificateDir}/harbor.crt"
        exit 1
    fi
else
    echo ">>>> ${HarborCertificateDir} directory not existed."
    exit 1
fi


### 10. harbor config yaml file modify ###
echo "===> 10. harbor config yaml file modify"
echo "#######################################################################################################"
##### 10-1.hostname Change #####
echo "---> 10-1.hostname Change"
sudo sed -i 's|^hostname:.*|hostname: '${IF_IPADDRESS}'|g' ${HarborInstallConfFile}
HarborConfHostnameIP=$(grep '^hostname:' ${HarborInstallConfFile} | cut -d':' -f2|tr -d ' ')
if [ "${IF_IPADDRESS}" = "${HarborConfHostnameIP}" ];then
    echo ">>>> Change Success hostname: ${IF_IPADDRESS}"
else
    echo ">>>> Change Failed hostname: ${IF_IPADDRESS}"
    exit 1
fi

##### 10-2. certificate & private key Change #####
echo "---> 10-2. certificate & private key Change"
for kind in certificate private_key
    do
        if [ "${kind}" = "certificate" ]; then
            sudo sed -i 's|  certificate:.*|  certificate: '${HarborCertificateDir}'/harbor.crt|g' ${HarborInstallConfFile}
        else
            sudo sed -i 's|  private_key:.*|  private_key: '${HarborCertificateDir}'/harbor.key|g' ${HarborInstallConfFile}
        fi

        CertDir=$(grep "${kind}:"  ${HarborInstallConfFile} | cut -d':' -f2 | tr -d ' ')
        if [ "$(dirname ${CertDir})" = "${HarborCertificateDir}" ]; then
            echo ">>>> Change Success ${kind} Location in ${HarborCertificateDir}"
        else
            echo ">>>> Change Failed ${kind} Location in ${HarborCertificateDir}"
            exit 1
        fi
done

##### 10-3. harbor admin passwd change #####
echo "---> 10-3. harbor admin passwd change"
sudo sed  -i 's|harbor_admin_password:.*|harbor_admin_password: '${HarborAdminPassword}'|g' ${HarborInstallConfFile}
HarborAdminPW=$(grep '^harbor_admin_password:' ${HarborInstallConfFile} | cut -d':' -f2|tr -d ' ')
if [ "${HarborAdminPW}" = "${HarborAdminPassword}" ];then
    echo ">>>> Change Success harbor admin password: ${HarborAdminPassword}"
else
    echo ">>>> Change Failed harbor admin password: ${HarborAdminPassword}"
    exit 1
fi

##### 10-4. data volumn directory change #####
echo "---> 10-4. data volumn directory change"
sudo sed  -i 's|data_volume:.*|data_volume: '${HarborDataStoreDir}'|g' ${HarborInstallConfFile}
HarborVolumnDir=$(grep '^data_volume:' ${HarborInstallConfFile} | cut -d':' -f2|tr -d ' ')
if [ "${HarborVolumnDir}" = "${HarborDataStoreDir}" ];then
    echo ">>>> Change Success hostname: ${HarborDataStoreDir}"
else
    echo ">>>> Change Failed hostname: ${HarborDataStoreDir}"
    exit 1
fi


### 11. Harbor Base Install ###
echo "===> 11. Harbor Base Install"
echo "#######################################################################################################"
sudo ${HarborInstallDir}/harbor/install.sh \
    --with-clair \
    --with-chartmuseum \
    | sudo tee ${HarborLogDir}/harbor-install.log


### 12. Harbor Docker-compose down
echo "===> 12. Harbor Docker-compose down"
echo "#######################################################################################################"
sudo docker-compose -f ${HarborInstallDir}/harbor/docker-compose.yml down


### 13. Database Task harbor-db container Docker run & Check
echo "===> 13. Database Task harbor-db container Docker run & Check"
echo "#######################################################################################################"
##### 13-1. Database Task harbor-db container Docker run
echo "===> 13-1. Database Task harbor-db container Docker run "
sudo docker run \
     -d \
     --name harbor-db \
     -v ${HarborRestoreDataDir}:/backup \
     -v ${CubeWork}/harbor/database:/var/lib/postgresql/data \
     goharbor/harbor-db:v${HarborVersion} "postgres"

##### 13-2. Database Task harbor-db container Docker run Check
echo "===> 13-2. Database Task harbor-db container Docker run Check "
sudo docker exec harbor-db pg_isready | grep "accepting connections"
sleep 10


### 14. Harbor db(postgres) execute : drop & create ###
echo "===> 14. Harbor db(postgres) drop & create"
echo "#######################################################################################################"
HarborDBList=("registry" "postgres" "notarysigner" "notaryserver")
Count=1
for dbjob in drop create
    do
    echo "---> 14-${Count}. Harbor db execute :  ${dbjob}"
    for dbname in ${HarborDBList[@]}
        do
            sudo docker exec harbor-db psql -U postgres -d template1 -c "${dbjob}  database  ${dbname};"
            echo ">>>> harbor-db postgres database ${dbname} => ${dbjob}"
    done
    (( Counr = Count + 1 ))
done


### 15. Harbor database restore copy & execute and registry https URL Change(=IF_IPADDRESS)
echo "===> 15. Harbor database restore copy & execute and registry https URL Change(=IF_IPADDRESS)"
echo "#######################################################################################################"
HarborDatabaseFileList=("registry.back" "postgres.back" "notarysigner.back" "notaryserver.back")
##### 15-1. Harbor database restore(cp)
echo "---> 15-1. Harbor database restore(cp)"
for DataFile in ${HarborDatabaseFileList[@]}
    do
        echo ">>>> harbor database ${DataFile} restore(cp) "
        sudo docker cp ${HarborRestoreDataDir}/harbor/db/${DataFile} harbor-db:/tmp/${DataFile}
done
##### 15-2. Harbor database restore execute
echo "---> 15-2. Harbor database restore execute"
for DataFile in ${HarborDatabaseFileList[@]}
    do
        BaseDBName=$(basename -s .back ${DataFile})
        echo ">>>> harbor database ${BaseDBName} execute"
        sudo docker exec harbor-db sh -c "psql -U postgres ${BaseDBName} < /tmp/${DataFile}"
done
##### 15-3. Harbor registry https URL Change(=IF_IPADDRESS)
### sudo docker exec harbor-db sh -c "psql -U postgres registry -c \"update properties set v='https://${IF_IPADDRESS}' where k='ext_endpoint'\""
echo "---> 15-3. Harbor registry https URL Change(=${IF_IPADDRESS})"
sudo docker exec harbor-db sh -c "psql -U postgres registry -c \"update properties set v='https://${IF_IPADDRESS}' where k='ext_endpoint'\""


### 16. Database Task harbor-db container Docker stop, rm
echo "===> 16. Database Task harbor-db container Docker stop, rm"
echo "#######################################################################################################"
echo ">>>> Database Task harbor-db container stop"
sudo docker stop harbor-db
echo ">>>> Database Task harbor-db container rm"
sudo docker rm harbor-db


### 17. Harbor registry / Chart_stroage / Secret Copy
echo "===> 17. Harbor registry / Chart_stroage / Secret Copy"
echo "#######################################################################################################"
HarborCopyList=("registry" "chart_storage" "secret")
for CpName in ${HarborCopyList[@]}
    do
        if [ "${CpName}" = "secret" ]; then
            sudo cp -R  ${HarborRestoreDataDir}/harbor/${CpName} ${CubeWork}/harbor/
        else
            sudo cp -rf ${HarborRestoreDataDir}/harbor/${CpName}/* ${CubeWork}/harbor/${CpName}
        fi
        echo ">>>> harbor ${CpName} copied"
done


### 18. harbor Certificate file(=ca.crt) to nginx configuration directory
echo "===> 18. copy harbor Certificate file(=ca.crt) to nginx configuration directory"
echo "#######################################################################################################"
##### 18-1 nginx cert directory check & create
if [ ! -d ${HarborInstallDir}/harbor/common/config/nginx/cert ]; then
    sudo mkdir -p ${HarborInstallDir}/harbor/common/config/nginx/cert/
fi
##### 18-2. copy Cert file(=ca.crt) to nginx conf-dir and config file check 
if [ -f  ${HarborCertificateDir}/ca.crt ]; then
    sudo cp ${HarborCertificateDir}/ca.crt ${HarborInstallDir}/harbor/common/config/nginx/cert/ca.crt
    echo ">>>> copy cert-file to nginx conf-dir(=${HarborInstallDir}/harbor/common/config/nginx/cert/)"
fi

NginxConfigCheck=$(sudo ls ${HarborInstallDir}/harbor/common/config/nginx/nginx.conf_origin 2>/dev/null)
if [ -z ${NginxConfigCheck} ]; then
    echo ">>>> Not Found Harbor Origin config backup file"
    echo ">>>> Next Task Progress"
else
    echo ">>>> Found Harbor config backup file"
    echo ">>>> Nginx File Origin restore"
    sudo rm -rf ${HarborInstallDir}/harbor/common/config/nginx/nginx.conf
    sudo mv ${HarborInstallDir}/harbor/common/config/nginx/nginx.conf_origin ${HarborInstallDir}/harbor/common/config/nginx/nginx.conf
fi
sudo cp -ap ${HarborInstallDir}/harbor/common/config/nginx/nginx.conf  ${HarborInstallDir}/harbor/common/config/nginx/nginx.conf_origin

ChunkLineNo=$(sudo cat ${HarborInstallDir}/harbor/common/config/nginx/nginx.conf | grep chunked_transfer_encoding -n | awk -F ':' '{print $1}')
ChunkLineNo=$(expr ${ChunkLineNo} + 1)   # ChunkLineNo = 58
echo ">>>> ChunkLineNo = ${ChunkLineNo}"

sudo awk 'NR=='"${ChunkLineNo}"'{print "    location /ca.crt {"}1' ${HarborInstallDir}/harbor/common/config/nginx/nginx.conf | sudo tee ${CubeDir}/temp/out_01
ChunkLineNo=$(expr ${ChunkLineNo} + 1)     # ChunkLineNo = 59
echo ">>>> ChunkLineNo = ${ChunkLineNo}"

sudo awk 'NR=='"${ChunkLineNo}"'{print "      alias /etc/nginx/cert/ca.crt;"}1' ${CubeDir}/temp/out_01 | sudo tee ${CubeDir}/temp/out_02 1>/dev/null
ChunkLineNo=$(expr ${ChunkLineNo} + 1)     # ChunkLineNo = 60
echo ">>>> ChunkLineNo = ${ChunkLineNo}"

sudo awk 'NR=='"${ChunkLineNo}"'{print "    }"}1' ${CubeDir}/temp/out_02 | sudo tee ${CubeDir}/temp/out_03 1>/dev/null
sudo cat < ${CubeDir}/temp/out_03 | sudo tee ${HarborInstallDir}/harbor/common/config/nginx/nginx.conf


### 19. Harbor Container running using docker-compose
echo "===> 19. Harbor Container running using docker-compose"
echo "#######################################################################################################"
if [ -d ${HarborDataStoreDir}/registry/docker ]; then
    sudo chown -R 10000.10000 ${HarborDataStoreDir}/registry/docker
    sudo docker-compose -f ${HarborInstallDir}/harbor/docker-compose.yml up -d
fi

### Harbor install and setup Complete
echo "===> Harbor install and setup Complete. connecting to https://${IF_IPADDRESS} use WEB Browser(chrome) "
echo "#######################################################################################################"

### DockerUser add to docker-group
for User in ${DockerUser}
    do
        sudo usermod -aG docker ${User}
done
sudo newgrp - docker


