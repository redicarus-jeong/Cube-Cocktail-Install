#!/usr/bin/env bash

### this script is Preinstall Kubernetes Masters
### date : 2022-06-16
### author : redicarus.jeong

CurrentPath=$(pwd)
ScriptHomeDir=${CurrentPatch}/script
RepositoryHostname="repository"
HarborHostname="harbor"
RepoPort=3777

### Incloud ENV File ###
HarborVersion="1.10.6"
CubeVersion="1.21"
MainDir="/APP"
CubeWork="${MainDir}/acorn"
CubeDir="${CubeWork}/cube"
CubeData="${CubeWork}/data"
CubeTmp="${MainDir}/acornsoft"
CubeExec="${MainDir}/cocktail"
AWSServer="disable"

if [ ! -d ${CubeWork}/cube/temp ]; then 
  sudo mkdir -p ${CubeWork}/cube/temp
fi

##### 1. ADD Package Repo ###
echo "====> 1. ADD Package Repo : script call = ${CurrentPath}/script/91.PKGRepoConnectSetup.sh ###"
if [ -f ${CurrentPath}/91.PKGRepoConnectSetup.sh ]; then
    sudo sh ${CurrentPath}/91.PKGRepoConnectSetup.sh
else
    sudo sh ${CurrentPath}/script/91.PKGRepoConnectSetup.sh
fi


SystemDefaultRPM=("net-tools" "wget" "epel-release" "openssl11" "nfs-utils" "yum-utils" "device-mapper-persistent-data" "lvm2" "jq")
##### 1. System Default Package install & cube temp directory create
echo "====> 1. System Default Package install & cube temp directory create"
echo " ---> 1-1. cube temp directory create"
if [ ! -d ${CubeTmp}/temp ]; then
    sudo mkdir -p ${CubeTmp}/temp
fi
if [ ! -d ${CubeWork} ]; then
    sudo mkdir -p ${CubeWork}
fi

echo " ---> 1-2. System Default Package install "
for rpmname in ${SystemDefaultRPM[@]}
    do
	    InstallResult=$(rpm -qa | grep ${rpmname} | wc -l)
		if [ ${InstallResult} -ge 1 ]; then
		    echo " >>>> yum re-install : ${rpmname}"
			sudo yum reinstall -y ${rpmname}
			
		elif [ ${InstallResult} -eq 0 ]; then
		    echo " >>>> yum install : ${rpmname}"
		    sudo yum install -y ${rpmname}
		else
		    echo " >>>> yum pkg rpm install failed."
			exit 0
		fi
done


##### 2. ETCD & Helm
WgetBinary=("helm" "sshpass" "etcd")
echo "====> 2. wget etcd & Helm binary from PKG Repository"
RepositoryIP=$(grep ${RepositoryHostname} /etc/hosts | awk 'NR==1 {print $1}')
RepoPingCount=$(ping -c 3 ${RepositoryIP} | grep received |cut -d',' -f2|awk '{print $1}' | sed 's/ //g')
if [  $RepoPingCount -ne 3 ]; then
    echo " >>>> Check CentOS-7.9 Private RPM Repository Server IP(=${RepositoryIP})"
    exit 1
else
    echo " >>>> wget ${WgetBinary[0]} "
    if [ ! -f ${CubeTmp}/cube/binary/${WgetBinary[0]} ]; then
	    sudo wget http://${RepositoryIP}:${RepoPort}/binary/${WgetBinary[0]}  -P  ${CubeTmp}/cube/binary/
        sudo chmod ug+x ${CubeTmp}/cube/binary/${WgetBinary[0]}
        sudo cp -pf ${CubeTmp}/cube/binary/${WgetBinary[0]}  /usr/local/bin/
    fi

    echo " >>>> wget ${WgetBinary[1]} "
    if [ ! -f ${CubeTmp}/cube/binary/${WgetBinary[1]} ]; then
	    sudo wget http://${RepositoryIP}:${RepoPort}/binary/${WgetBinary[1]}  -P  ${CubeTmp}/cube/binary/
        sudo chmod ug+x ${CubeTmp}/cube/binary/${WgetBinary[1]}
        sudo cp -pf ${CubeTmp}/cube/binary/${WgetBinary[1]}  /usr/local/bin/
    fi
    
    echo " >>>> wget ${WgetBinary[2]} "
    if [ ! -f ${CubeTmp}/cube/etcd/${WgetBinary[2]} ]; then
        echo " >>>> wget ${WgetBinary[0]} failed"
        sudo wget http://${RepositoryIP}:${RepoPort}/etcd/${WgetBinary[2]}  -P  ${CubeTmp}/cube/etcd/
		sudo chmod ug+x ${CubeTmp}/cube/etcd/${WgetBinary[2]}
        sudo cp -pf ${CubeTmp}/cube/etcd/${WgetBinary[2]}  /usr/local/bin/
    fi

fi    


### 3. containerd running check & install
echo "====> 3. containerd running check & install"
ActiveRes=$(systemctl is-active containerd)
if [ "${ActiveRes}" = "active" ] && [ $(rpm -qa|grep containerd|wc -l) -eq 0 ]; then
    echo " >>>> Containerd running"
else
    echo " >>>> Containerd.io install"
	sudo yum install -y containerd.io
fi    
    

##### 4. kubernate : kubeadm / kubectl / kubelet check & install
echo "====> 4. kubernate : kubeadm / kubectl / kubelet check & install"
KubeTools=("kubeadm" "kubectl" "kubelet")
for KubeName in ${KubeTools[@]}
    do
        KubeVersion=$(sudo yum --showduplicate list ${KubeName} --disableexcludes=kubernetes | grep ${CubeVersion} | awk {'print $2'} | sort -t '.' -k3 -n | uniq | tail -n 1)
        if [ $(echo ${KubeVersion}) -ge 5]; then
            echo "  >>> yum install ${KubeName}-${KubeVersion}"
            sudo yum install -y ${KubeName}-${KubeVersion}  --disableexcludes=kubernetes 
        else
            echo "  >>> Not found ${KubeName}-${KubeVersion} in PKG Repository(hostname=${RepositoryHostname})"
            exit 1
        fi
done


##### 5. Certificate ca.crt copy in Harbor Registry  
echo "===+> 5. Certificate ca.crt copy in Harbor Registry "
HarborURL=$(grep ${HarborHostname} /etc/hosts | awk 'NR==1 {print $2}')
HarborPingCount=$(ping -c 3 ${HarborURL} | grep received |cut -d',' -f2|awk '{print $1}' | sed 's/ //g')
if [  $HarborPingCount -ne 3 ]; then
    echo " >>>> Check Harbor Registry Server IP(=${HarborURL})"
    exit 1
else
    if [ ! -d /etc/docker/certs.d/${HarborURL} ]; then
        sudo mkdir -p /etc/docker/certs.d/${HarborURL}
    fi
    echo "  >>> https://${HarborURL}/ca.crt copy to /etc/docker/certs.d/${HarborURL}/"
    sudo wget  https://${HarborURL}/ca.crt  --no-check-certificate  -P  /etc/docker/certs.d/${HarborURL}/
fi    


### 6. Firewalld disable
echo "====> 6. firewalld disable"
echo "#######################################################################################################"
IsActive=$(systemctl is-active firewalld)
IsEnable=$(systemctl is-enabled firewalld)
if [ "${IsActive}" = "active" ]; then
    sudo systemctl stop firewalld
fi
if [ "${IsEnable}" = "enabled" ]; then
    sudo systemctl disable firewalld
fi


### 7. Selinux permissive (disable)
echo "====> 7. Selinux mode change to permissive"
echo "#######################################################################################################"
SeLinuxInFileMode=$(grep ^'SELINUX=' /etc/selinux/config | cut -d'=' -f2)
sudo setenforce 0
if [ "${SeLinuxInFileMode}" = "enforcing" ]; then
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
fi




