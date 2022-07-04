#!/usr/bin/env bash

### this script is Preinstall Kubernetes Masters
### date : 2022-06-16
### author : redicarus.jeong
### description
### 2022-06-30 : Change environment variable names to uppercase

if [ ! -d ${CUBE_WORK}/cube/temp ]; then 
  sudo mkdir -p ${CUBE_WORK}/cube/temp
fi

##### 1. ADD Package Repo ###
echo "====> 1. ADD Package Repo : script call = ${CURRENT_PATH}/script/91.PKGRepoConnectSetup.sh ###"
if [ -f ${CURRENT_PATH}/91.PKGRepoConnectSetup.sh ]; then
    sudo sh ${CURRENT_PATH}/91.PKGRepoConnectSetup.sh
else
    sudo sh ${CURRENT_PATH}/script/91.PKGRepoConnectSetup.sh
fi


SYSTEM_DEFAULT_RPM=("net-tools" "wget" "epel-release" "openssl11" "nfs-utils" "yum-utils" "device-mapper-persistent-data" "lvm2" "jq")
##### 1. System Default Package install & cube temp directory create
echo "====> 1. System Default Package install & cube temp directory create"
echo " ---> 1-1. cube temp directory create"
if [ ! -d ${CUBE_TEMP}/temp ]; then
    sudo mkdir -p ${CUBE_TEMP}/temp
fi
if [ ! -d ${CUBE_WORK} ]; then
    sudo mkdir -p ${CUBE_WORK}
fi

echo " ---> 1-2. System Default Package install "
for RPM_NAME in ${SYSTEM_DEFAULT_RPM[@]}
    do
	    INSTALL_RESULT=$(rpm -qa | grep ${RPM_NAME} | wc -l)
		if [ ${INSTALL_RESULT} -ge 1 ]; then
		    echo " >>>> yum re-install : ${RPM_NAME}"
			sudo yum reinstall -y ${RPM_NAME}
			
		elif [ ${INSTALL_RESULT} -eq 0 ]; then
		    echo " >>>> yum install : ${RPM_NAME}"
		    sudo yum install -y ${RPM_NAME}
		else
		    echo " >>>> yum pkg rpm install failed."
			exit 0
		fi
done


##### 2. ETCD & Helm
WGET_BINARY=("helm" "sshpass" "etcd" "etcdctl")
echo "====> 2. wget etcd & Helm binary from PKG Repository"
REPOSITORY_IP=$(grep ${REPOSITORY_HOSTNAME} /etc/hosts | awk 'NR==1 {print $1}')
REPOSITORY_PING_COUNT=$(ping -c 3 ${REPOSITORY_IP} | grep received |cut -d',' -f2|awk '{print $1}' | sed 's/ //g')
if [  $REPOSITORY_PING_COUNT -ne 3 ]; then
    echo " >>>> Check CentOS-7.9 Private RPM Repository Server IP(=${REPOSITORY_IP})"
    exit 1
else
    echo " >>>> wget ${WGET_BINARY[0]} "
    ### Only Master01 
    if [ ! -f ${CUBE_TEMP}/cube/binary/${WGET_BINARY[0]} ]; then
	    sudo wget http://${REPOSITORY_IP}:${REPO_PORT}/binary/${WGET_BINARY[0]}  -P  ${CUBE_TEMP}/cube/binary/
        sudo chmod ug+x ${CUBE_TEMP}/cube/binary/${WGET_BINARY[0]}
        sudo cp -pf ${CUBE_TEMP}/cube/binary/${WGET_BINARY[0]}  /usr/local/bin/
    fi

    ### All Master & Node
    echo " >>>> wget ${WGET_BINARY[1]} "
    if [ ! -f ${CUBE_TEMP}/cube/binary/${WGET_BINARY[1]} ]; then
	    sudo wget http://${REPOSITORY_IP}:${REPO_PORT}/binary/${WGET_BINARY[1]}  -P  ${CUBE_TEMP}/cube/binary/
        sudo chmod ug+x ${CUBE_TEMP}/cube/binary/${WGET_BINARY[1]}
        sudo cp -pf ${CUBE_TEMP}/cube/binary/${WGET_BINARY[1]}  /usr/local/bin/
    fi
    
    ### All Master
    echo " >>>> wget ${WGET_BINARY[2]} "
    if [ ! -f ${CUBE_TEMP}/cube/etcd/${WGET_BINARY[2]} ]; then
        sudo wget http://${REPOSITORY_IP}:${REPO_PORT}/etcd/${WGET_BINARY[2]}  -P  ${CUBE_TEMP}/cube/etcd/
		sudo chmod ug+x ${CUBE_TEMP}/cube/etcd/${WGET_BINARY[2]}
        sudo cp -pf ${CUBE_TEMP}/cube/etcd/${WGET_BINARY[2]}  /usr/local/bin/
    fi

    ### All Master
    echo " >>>> wget ${WGET_BINARY[3]} "
    if [ ! -f ${CUBE_TEMP}/cube/etcd/${WGET_BINARY[3]} ]; then
        sudo wget http://${REPOSITORY_IP}:${REPO_PORT}/etcd/${WGET_BINARY[3]}  -P  ${CUBE_TEMP}/cube/etcd/
		sudo chmod ug+x ${CUBE_TEMP}/cube/etcd/${WGET_BINARY[3]}
        sudo cp -pf ${CUBE_TEMP}/cube/etcd/${WGET_BINARY[3]}  /usr/local/bin/
    fi
fi    


### 3. containerd running check & install
echo "====> 3. containerd running check & install"
ACTIVE_RES=$(systemctl is-active containerd)
if [ "${ACTIVE_RES}" = "active" ] && [ $(rpm -qa|grep containerd|wc -l) -eq 0 ]; then
    echo " >>>> Containerd running"
else
    echo " >>>> Containerd.io install"
	sudo yum install -y containerd.io
fi    
    

##### 4. kubernate : kubeadm / kubectl / kubelet check & install
echo "====> 4. kubernate : kubeadm / kubectl / kubelet check & install"
KUBE_TOOLS=("kubeadm" "kubectl" "kubelet")
for KUBE_NAME in ${KUBE_TOOLS[@]}
    do
        KUBE_VERSION=$(sudo yum --showduplicate list ${KUBE_NAME} --disableexcludes=kubernetes | grep ${CUBE_VER} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1)
        if [ $(echo ${KUBE_VERSION}) -ge 5]; then
            echo "  >>> yum install ${KUBE_NAME}-${KUBE_VERSION}"
            sudo yum install -y ${KUBE_NAME}-${KUBE_VERSION}  --disableexcludes=kubernetes 
        else
            echo "  >>> Not found ${KUBE_NAME}-${KUBE_VERSION} in PKG Repository(hostname=${REPOSITORY_HOSTNAME})"
            exit 1
        fi
done


##### 5. Certificate ca.crt copy in Harbor Registry  
echo "====> 5. Certificate ca.crt copy in Harbor Registry "
HARBOR_URL=$(grep ${HARBOR_HOSTNAME} /etc/hosts | awk 'NR==1 {print $2}')
HARBOR_PING_COUNT=$(ping -c 3 ${HARBOR_URL} | grep received |cut -d',' -f2|awk '{print $1}' | sed 's/ //g')
if [  $HARBOR_PING_COUNT -ne 3 ]; then
    echo " >>>> Check Harbor Registry Server IP(=${HARBOR_URL})"
    exit 1
else
    if [ ! -d /etc/docker/certs.d/${HARBOR_URL} ]; then
        sudo mkdir -p /etc/docker/certs.d/${HARBOR_URL}
    fi
    echo "  >>> https://${HARBOR_URL}/ca.crt copy to /etc/docker/certs.d/${HARBOR_URL}/"
    sudo wget  https://${HARBOR_URL}/ca.crt  --no-check-certificate  -P  /etc/docker/certs.d/${HARBOR_URL}/
fi    


### 6. Firewalld disable
echo "====> 6. firewalld disable"
echo "#######################################################################################################"
IS_ACTIVE=$(systemctl is-active firewalld)
IS_ENABLE=$(systemctl is-enabled firewalld)
if [ "${IS_ACTIVE}" = "active" ]; then
    sudo systemctl stop firewalld
fi
if [ "${IS_ENABLE}" = "enabled" ]; then
    sudo systemctl disable firewalld
fi


### 7. Selinux permissive (disable)
echo "====> 7. Selinux mode change to permissive"
echo "#######################################################################################################"
SELINUX_FILE_MODE=$(grep ^'SELINUX=' /etc/selinux/config | cut -d'=' -f2)
sudo setenforce 0
if [ "${SELINUX_FILE_MODE}" = "enforcing" ]; then
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
fi




