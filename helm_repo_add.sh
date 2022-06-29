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



HELMREPONAME=$1

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

