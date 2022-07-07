#!/usr/bin/env bash

### This script is only Private Repository Setup Script on CentOS-7.9 
### This script has been separated from the cube-5.2.3 installation script that name is 91_private_registry.sh.
### Modified Date : 2022-06-08
### Author : redicarus.jeong

##### Install & Setup variable define
RepositoryTarFileName="$1"
if [ ! -f $RepositoryTarFileName ]; then
    echo; echo "---> Not Found $RepositoryTarFileName in current directory"
    echo "---> usage: sh $0 <tar-file.tar.gz>"; echo
    exit 1
fi

RepositoryName="CentOS-7.9_RPMRepo"
BaseRepositoryDirectory="/PrivateRepo"
CreateRepoPKGDirectory="${RepositoryDirectory}/79rpm/00_createrepo"

OS_TYPE=`grep ^NAME /etc/os-release | grep -oP '"\K[^"]+' | awk '{print $1}' | tr '[:upper:]' '[:lower:]'`
OS_VERSION=`cat /etc/centos-release | awk {'print $4'} | awk -F "." {'print $1 "." $2'}`

### AWS Check "enable" or "disable"
if [ "${OS_TYPE}" = "centos" ]; then
    AWS_SERVER=disable
elif [ "${OS_TYPE}" = "amazon" ]; then
    AWS_SERVER=enable
else
    echo; echo "-- Check the OS Type! This Script can be run on centos or amazon."; echo
    exit 1
fi
echo
echo "---> OS Type = ${OS_TYPE}"
echo "---> OS Version = ${OS_VERSION}"
echo "---> AWS Server = ${AWS_SERVER}"
echo

### 1. directory check and make for private repository 
echo "===> 1. directory check and make for private repository "
echo "#######################################################################################################"
echo "---> 1. Check Base Repository directory = ${BaseRepositoryDirectory}"
if [ ! -d "${BaseRepositoryDirectory}" ]; then
    sudo mkdir -p ${BaseRepositoryDirectory}
fi

### 2. tar file extrect in Base Repository Directory
echo "===> 2. tar file extrect in ${BaseRepositoryDirectory}"
echo "#######################################################################################################"
sudo tar xzf ${RepositoryTarFileName} -C ${BaseRepositoryDirectory}
if [ $? -eq 0 ]; then
    sudo  mv  ${BaseRepositoryDirectory}  ${BaseRepositoryDirectory}/${RepositoryName}/79rpm
    if [ ! -d ${BaseRepositoryDirectory}/${RepositoryName}/79rpm ]; then
        echo "---> change name failed for repository. check ${RepositoryName}/79rpm directory name in ${BaseRepositoryDirectory}"
        exit 1
    fi
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
SeIsEnable=$(sestatus | grep ^"SELinux status:" | cut -d':' -f2 | sed 's/ //g')
SeMode=$(sestatus | grep ^"Current mode:" | cut -d':' -f2 | sed 's/ //g')              # enforcing / permissive / disabled
SeInFileMode=$(grep ^'SELINUX=' /etc/selinux/config | cut -d'=' -f2)
sudo setenforce 0
if [ "${SeInFileMode}" = "enforcing" ]; then
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
fi

### 5. Create Private RPM PKG Repository
echo "===> 5. Create local Private repository"
echo "#######################################################################################################"
sudo mv /etc/yum.repos.d /etc/yum.repos.d.bak
sudo mkdir -p /etc/yum.repos.d
sudo chown root:root /etc/yum.repos.d
sudo chmod 0755 /etc/yum.repos.d
sudo touch /etc/yum.repos.d/79rpm.repo
cat << EOF | sudo tee /etc/yum.repos.d/79rpm.repo
[CentOS-7.9_Private_Repository]
name=CentOS-7.9 Everthing and Cube rpm repository
baseurl=file://${BaseRepositoryDirectory}/${RepositoryName}
gpgcheck=0
enabled=1
EOF

CreateRepoInstallCheck=$(rpm -qa createrepo | wc -l)
if [ $CreateRepoInstallCheck -ne 1 ]; then
    sudo yum install -y --disablerepo=*  ${BaseRepositoryDirectory}/${RepositoryName}/00_createrepo/*
fi
sudo yum clean all
sudo createrepo ${BaseRepositoryDirectory}/${RepositoryName}
sudo yum repolist

### 6. nginx install & setup
echo "===> 6. nginx install and setup"
echo "#######################################################################################################"
sudo yum remove nginx -y
sudo rm -rf /etc/nginx/nginx.conf.rpmsave
sudo yum install -y nginx 

sudo sed -i -r "s/listen       80/listen       3777/" /etc/nginx/nginx.conf
sudo sed -i -r "s/listen       \[\:\:\]\:80/listen       \[\:\:\]\:3777/" /etc/nginx/nginx.conf
sudo sed -i 's|root         /usr/share/nginx/html|root         '${BaseRepositoryDirectory}/${RepositoryName}'|g' /etc/nginx/nginx.conf
sudo systemctl restart nginx
sudo systemctl enable nginx
sudo systemctl status nginx

echo "===> script end"
echo "#######################################################################################################"

