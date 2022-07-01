#!/usr/bin/env bash

### This script is only connect to Private Harbor Registry on CentOS-7.9 
### Modified Date : 2022-06-16
### Author : redicarus.jeong

CurrentPath=$(pwd)
ScriptHomeDir=${CurrentPatch}/script/Private
RepositoryHostname="repoharbornfs"
HarborHostname="registry"
RepoPort=3777

IFName="enp0s8"
IFIPClass=$(ip addr show dev ${IFName} scope global |grep inet|awk '{print $2}'|cut -d'.' -f1,2,3)

### Incloud ENV File ###
HarborUserID="acloud"
HarborUserPW="@c0rnWks@2"
HarborRepoList=("cube" "cocktail" "cocktail-addon")
HarborVersion="1.10.6"
CubeVersion="1.21"
MainDir="/APP"
CubeWork="${MainDir}/acorn"
CubeDir="${CubeWork}/cube"
CubeData="${CubeWork}/data"
CubeTmp="${MainDir}/acornsoft"
CubeExec="${MainDir}/cocktail"
AWSServer="disable"

HarborURL=$(grep ${HarborHostname} /etc/hosts | grep ${IFIPClass} | awk 'NR==1 {print $1}')
HarborPingCount=$(ping -c 3 ${HarborURL} | grep received |cut -d',' -f2|awk '{print $1}' | sed 's/ //g')

##### 1. ADD Package Repo ###
echo "====> 1. ADD Package Repo : script call = ${CurrentPath}/script/91.PKGRepoConnectSetup.sh ###"
if [ -f ${CurrentPath}/script/91.PKGRepoConnectSetup.sh ]; then
    sudo sh ${CurrentPath}/script/91.PKGRepoConnectSetup.sh
elif [ -f ${CurrentPath}/Private/91.PKGRepoConnectSetup.sh ]; then
    sudo sh ${CurrentPath}/Private/91.PKGRepoConnectSetup.sh
else
    echo "  >>> Not Found 91.PKGRepoConnectSetup.sh"
fi

SystemDefaultRPM=("net-tools" "wget" "epel-release" "openssl11-libs" "nfs-utils" "yum-utils" "device-mapper-persistent-data" "lvm2" "jq")
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


##### 2. wget Helm & sshpass in PKG Repository
WgetBinary=("helm" "sshpass")
echo "====> 2. wget helm & sshpass binary from PKG Repository"
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
fi    


##### 3. Certificate ca.crt copy in Harbor Registry  
echo "===+> 3. Certificate ca.crt copy in Harbor Registry "
if [  $HarborPingCount -ne 3 ]; then
    echo " >>>> Check Harbor Registry Server IP(=${HarborURL})"
    exit 1
else
    if [ ! -d /etc/docker/certs.d/${HarborURL} ]; then
        sudo mkdir -p /etc/docker/certs.d/${HarborURL}
    fi
    echo "  >>> get https://${HarborURL}/ca.crt copy "
    sudo wget  --no-check-certificate  https://${HarborURL}/ca.crt  -P  /etc/docker/certs.d/${HarborURL}/
fi    


##### 4. Helm Repository Add
echo "====> 4. Helm repository add to chartmuseum of in Harbor registry"
helmRepoCount=0
if [ -f /etc/docker/certs.d/${HarborURL}/ca.crt ]; then
    for RepoName in  ${HarborRepoList[@]}
        do
            sudo  helm  repo  add  \
                       --ca-file  /etc/docker/certs.d/${HarborURL}/ca.crt   \
                       --username=${HarborUserID}  --password=${HarborUserPW}  \
                       ${RepoName}  https://${HarborURL}/chartrepo/${RepoName} 
            echo "  >>> ${RepoName} : helm repository add success"
            (( helmRepoCount = helmRepoCount + 1 ))
    done
else
    echo "  >>> helm repository add failed"
    echo "  >>> Not Found Certificate file(=/etc/docker/certs.d/${HarborURL}/ca.crt)"
    exit 1
fi



##### 5. Helm repository update & check
if [ ${#HarborRepoList[@]} -eq ${helmRepoCount} ]; then
    sudo helm repo update
    echo "------------------------------------------------------------"
    sudo helm repo list
    echo "------------------------------------------------------------"
fi


echo "#################### Helm Repository add complete ################"
