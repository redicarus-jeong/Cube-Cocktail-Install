#!/usr/bin/env bash

### This script is only connect to Private Repository Setup on CentOS-7.9 
### Modified Date : 2022-06-13
### Author : redicarus.jeong

export CurrentPath=$(pwd)
export IFName="enp0s8"
export IF_IPADDRESS=$(ip addr show dev ${IFName} scope global |grep inet|awk '{print $2}'|cut -d'/' -f1)
export RepositoryHostname="repository"
export RepoPort=3777

### Connect to Local Private PKG Repository on CentOS-7.9
echo "#############################################################"
echo "### Connect to Local Private PKG Repository on CentOS-7.9 ###"
echo "#############################################################"
### 1. yum.repos.d backup
echo;echo "===> 1. yum.repos.d backup"
if [ -d /etc/yum.repos.d.backup ]; then
    sudo mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d.backup/
else
    sudo mv -f /etc/yum.repos.d /etc/yum.repos.d.backup
    sudo mkdir -p /etc/yum.repos.d
    sudo chown root:root /etc/yum.repos.d
    sudo chmod 0755 /etc/yum.repos.d
fi

### 2. Private Repository repo file create or modify in yum.repos.d
echo;echo "===> 2. Private Repository repo file create or modify in yum.repos.d"

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
if [ -z ${RepositoryIP} ]; then
    echo ">>>> Not Found hostname in /etc/hosts. Change RepositoryHostname this script"
    exit 1
fi
RepoPingCount=$(ping -c 3 ${RepositoryIP} | grep received |cut -d',' -f2|awk '{print $1}' | sed 's/ //g')
if [  $RepoPingCount -ne 3 ]; then
    echo ">>>> CentOS-7.9 Private RPM Repository is not running. Checking PKG Repo.Server IP=${RepositoryIP}"
    exit 1
else
    echo ">>>> CentOS-7.9 Private RPM Repository is running. PKG Repo.Server IP=${RepositoryIP}"
    if [ ! -f /etc/yum.repos.d/79rpm.repo ]; then
        echo ">>>> Not found 79rpm.repo file in /etc/yum.repos.d "
        echo ">>>> Create a Repo file creation and connect to 79repo PKG Repository Server"
        ##### function is yumrepo_modify call 
        yumrepo_modify ${RepositoryIP} ${RepoPort}
    else
        PKGRepoBaseURL=$(grep baseurl /etc/yum.repos.d/79rpm.repo | cut -d':' -f1 | cut -d'=' -f2 ) 
        if [ "${PKGRepoBaseURL}" = "file" ];then
            ##### function is yumrepo_modify call 
            yumrepo_modify ${RepositoryIP} ${RepoPort}
        fi
        echo "-------------------------------------------"
        sudo cat /etc/yum.repos.d/79rpm.repo
        echo "-------------------------------------------"    
    fi
    echo;echo ">>>> yum clean all"
    sudo yum clean all

    echo;echo ">>>> yum repolist all"
    sudo yum repolist all
fi    

echo ">>>> completed connect to PKG Repository Server"
echo "###############################################"

