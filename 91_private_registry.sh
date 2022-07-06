#!/bin/bash

centos () {
  echo "### SYSTEM Default Package install ###"
  if [ ${AWS_SERVER} == "enable" ]; then
    sudo yum install -y --disablerepo=* ${CUBE_TMP}/cube/rpm/aws-centos-7/00_localrepo/00_createrepo/*
  fi
  sudo yum install -y --disablerepo=* ${CUBE_TMP}/cube/rpm/${OS_VERSION}/00_localrepo/00_createrepo/*

  sleep 5

  echo "### Firewalld Disable ###"
  sudo service firewalld stop
  sudo systemctl disable firewalld

  echo "### Selinux Disable ###"
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

  echo "### Binary File Copy ###"
  sudo cp -ap ${CUBE_TMP}/cube/binary/* /usr/local/bin/
  sudo ln -s /usr/local/bin/helm /usr/bin/helm
  sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose


  ############################
  ### Private Package Repo ###
  ############################

  ### create cocktail directroy
  sudo rm -rf ${CUBE_EXEC}/cube
  sudo mkdir -p ${CUBE_EXEC}/cube
  sudo cp -ap ${CUBE_TMP}/cube ${CUBE_EXEC}/

  ### Private Package Repo
  sudo mkdir -p ${CUBE_EXEC}/private_rpm/79rpm
  sudo mkdir -p ${CUBE_EXEC}/private_rpm/aws77rpm
  sudo mkdir -p ${CUBE_EXEC}/private_rpm/etcd
  sudo mkdir -p ${CUBE_EXEC}/private_rpm/helm
  sudo mkdir -p ${CUBE_EXEC}/private_rpm/sshpass

  sudo find ${CUBE_EXEC}/cube/rpm/7.9 -name "*.rpm" -exec cp -ap {} ${CUBE_EXEC}/private_rpm/79rpm/ \;
  
  sudo mv ${CUBE_TMP}/cube/binary/helm ${CUBE_EXEC}/private_rpm/helm/
  sudo mv ${CUBE_TMP}/cube/binary/sshpass ${CUBE_EXEC}/private_rpm/sshpass/
  sudo mv ${CUBE_TMP}/cube/etcd/etcd-download-test/etcd ${CUBE_EXEC}/private_rpm/etcd/
  sudo mv ${CUBE_TMP}/cube/etcd/etcd-download-test/etcdctl ${CUBE_EXEC}/private_rpm/etcd/

  sudo createrepo ${CUBE_EXEC}/private_rpm/79rpm
  
  sudo mv /etc/yum.repos.d /etc/yum.repos.d.bak
  sudo mkdir -p /etc/yum.repos.d
  sudo chown root:root /etc/yum.repos.d
  sudo chmod 0755 /etc/yum.repos.d

  if [ ${AWS_SERVER} == "enable" ]; then
    sudo touch /etc/yum.repos.d/aws77rpm.repo
cat <<EOF | sudo tee /etc/yum.repos.d/aws77rpm.repo
[aws77rpm]
name=aws77rpm repository
baseurl=file://${CUBE_EXEC}/private_rpm/aws77rpm
gpgcheck=0
enabled=1
EOF

  elif [ ${OS_VERSION} == "7.9" ]; then
    sudo touch /etc/yum.repos.d/79rpm.repo
cat <<EOF | sudo tee /etc/yum.repos.d/79rpm.repo
[79rpm]
name=79rpm repository
baseurl=file://${CUBE_EXEC}/private_rpm/79rpm
gpgcheck=0
enabled=1
EOF
  else
    echo "Check Your OS release"
    exit 0
  fi

  ### install nginx
  sudo yum remove nginx -y
  sudo rm -rf /etc/nginx/nginx.conf.rpmsave
  sudo yum install nginx -y

  sudo sed -i -r "s/listen       80/listen       3777/" /etc/nginx/nginx.conf
  sudo sed -i -r "s/listen       \[\:\:\]\:80/listen       \[\:\:\]\:3777/" /etc/nginx/nginx.conf
  sudo sed -i 's|root         /usr/share/nginx/html|root         '${CUBE_EXEC}'/private_rpm|g' /etc/nginx/nginx.conf
  sudo systemctl restart nginx
}

ubuntu () {
  sudo echo "### Firewalld Disable ###"
  sudo service ufw stop
  sudo systemctl disable ufw

  echo "### Binary File Copy ###"
  sudo cp -ap ${CUBE_TMP}/cube/binary/* /usr/local/bin/
  sudo ln -s /usr/local/bin/helm /usr/bin/helm
  sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

  ############################
  ### Private Package Repo ###
  ############################

  ### create cocktail directroy
  sudo rm -rf ${CUBE_EXEC}/cube
  sudo mkdir -p ${CUBE_EXEC}/cube
  sudo cp -ap ${CUBE_TMP}/cube ${CUBE_EXEC}/

  ### Private Package Repo
  sudo mkdir -p ${CUBE_EXEC}/private_dpkg/1804dpkg
  sudo mkdir -p ${CUBE_EXEC}/private_dpkg/2004dpkg
  sudo mkdir -p ${CUBE_EXEC}/private_dpkg/etcd
  sudo mkdir -p ${CUBE_EXEC}/private_dpkg/helm
  sudo mkdir -p ${CUBE_EXEC}/private_dpkg/sshpass

  sudo find ${CUBE_EXEC}/cube/dpkg/1804 -name "*.deb" -exec cp -ap {} ${CUBE_EXEC}/private_dpkg/1804dpkg/ \;
  sudo find ${CUBE_EXEC}/cube/dpkg/2004 -name "*.deb" -exec cp -ap {} ${CUBE_EXEC}/private_dpkg/2004dpkg/ \;

  sudo mv ${CUBE_TMP}/cube/binary/helm ${CUBE_EXEC}/private_dpkg/helm/
  sudo mv ${CUBE_TMP}/cube/binary/sshpass ${CUBE_EXEC}/private_dpkg/sshpass/
  sudo mv ${CUBE_TMP}/cube/etcd/etcd-download-test/etcd ${CUBE_EXEC}/private_dpkg/etcd/
  sudo mv ${CUBE_TMP}/cube/etcd/etcd-download-test/etcdctl ${CUBE_EXEC}/private_dpkg/etcd/

  ### install nginx

  status=1
  until [ $status == 0 ] # retry command on failure
  do
    sudo dpkg -i ${CUBE_TMP}/cube/dpkg/${OS_VERSION}/00_localrepo/01_nginx/*
    status=$?
  done

  sudo sed -i -r "s/listen 80 default_server/listen 3777/" /etc/nginx/sites-enabled/default
  sudo sed -i -r "s/listen \[\:\:\]\:80 default_server/listen \[\:\:\]\:3777/" /etc/nginx/sites-enabled/default
  sudo sed -i 's|/var/www/html|'${CUBE_EXEC}'/private_dpkg|g' /etc/nginx/sites-enabled/default


  sudo systemctl stop nginx
  sudo systemctl daemon-reload
  sudo systemctl enable nginx
  sudo systemctl start nginx

  echo "### SYSTEM Default Package install ###"
  sudo dpkg -i ${CUBE_TMP}/cube/dpkg/${OS_VERSION}/00_localrepo/00_dpkg-dev/* #dpkg-dev
  sudo apt --fix-broken install -y
  sleep 5

  # set Private Packages
  export CUBE_EXEC #Keep ENV Var
  cd ${CUBE_EXEC}/private_dpkg/1804dpkg/
  sudo dpkg-scanpackages -m ./ /dev/null | sudo -E sh -c 'gzip -c > ${CUBE_EXEC}/private_dpkg/1804dpkg/Packages.gz'
  cd ${CUBE_EXEC}/private_dpkg/2004dpkg/
  sudo dpkg-scanpackages -m ./ /dev/null | sudo -E sh -c 'gzip -c > ${CUBE_EXEC}/private_dpkg/2004dpkg/Packages.gz'
  cd ${CURRENT_PATH}
}

rocky() {
  echo "### Firewalld Disable ###"
  sudo service firewalld stop
  sudo systemctl disable firewalld

  echo "### Selinux Disable ###"
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

  echo "### Binary File Copy ###"
  sudo cp -ap ${CUBE_TMP}/cube/binary/* /usr/local/bin/
  sudo ln -sf /usr/local/bin/helm /usr/bin/helm
  sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

  ############################
  ### Private Package Repo ###
  ############################

  ### create cocktail directroy
  sudo rm -rf ${CUBE_EXEC}/cube
  sudo mkdir -p ${CUBE_EXEC}/cube
  sudo cp -ap ${CUBE_TMP}/cube ${CUBE_EXEC}/

  ### Private Package Repo
  sudo mkdir -p ${CUBE_EXEC}/private_rpm/8.5
  sudo mkdir -p ${CUBE_EXEC}/private_rpm/rocky
  sudo mkdir -p ${CUBE_EXEC}/private_rpm/etcd
  sudo mkdir -p ${CUBE_EXEC}/private_rpm/helm
  sudo mkdir -p ${CUBE_EXEC}/private_rpm/sshpass

  sudo cp -apr ${CUBE_EXEC}/cube/rpm/8.5/* ${CUBE_EXEC}/private_rpm/8.5/
  sudo rm -rf ${CUBE_EXEC}/private_rpm/8.5/Cube/createrepo
  sudo rm -rf ${CUBE_EXEC}/private_rpm/8.5/Cube/nginx
  #sudo find ${CUBE_EXEC}/cube/rpm/8.5/Cube -name "*.rpm" -exec cp -ap {} ${CUBE_EXEC}/private_rpm/8.5/Cube/ \;
  
  sudo mv ${CUBE_TMP}/cube/binary/helm ${CUBE_EXEC}/private_rpm/helm/
  sudo mv ${CUBE_TMP}/cube/binary/sshpass ${CUBE_EXEC}/private_rpm/sshpass/
  sudo mv ${CUBE_TMP}/cube/etcd/etcd-download-test/etcd ${CUBE_EXEC}/private_rpm/etcd/
  sudo mv ${CUBE_TMP}/cube/etcd/etcd-download-test/etcdctl ${CUBE_EXEC}/private_rpm/etcd/

  sudo yum install -y --disablerepo=* ${CUBE_TMP}/cube/rpm/8.5/Cube/createrepo/*

  sudo createrepo ${CUBE_EXEC}/private_rpm/8.5
  sudo createrepo ${CUBE_EXEC}/private_rpm/rocky

  sudo mv /etc/yum.repos.d /etc/yum.repos.d.bak
  sudo mkdir -p /etc/yum.repos.d
  sudo chown root:root /etc/yum.repos.d
  sudo chmod 0755 /etc/yum.repos.d

  if [ ${OS_VERSION} == "8.5" ]; then
    sudo touch /etc/yum.repos.d/cube-rocky.repo
cat <<EOF | sudo tee /etc/yum.repos.d/cube-rocky.repo
[baseos]
name=Rocky Linux $releasever - BaseOS
baseurl=file://${CUBE_EXEC}/private_rpm/8.5/BaseOS
gpgcheck=0
enabled=1

[appstream]
name=Rocky Linux $releasever - AppStream
baseurl=file://${CUBE_EXEC}/private_rpm/8.5/AppStream
gpgcheck=0
enabled=1

[cube-rocky]
name=cube kubernetes repository
baseurl=file://${CUBE_EXEC}/private_rpm/8.5/Cube
gpgcheck=0
enabled=1
EOF

  else
    echo "Check Your OS release"
    exit 0
  fi


  ### install nginx
  sudo yum remove nginx -y
  sudo rm -rf /etc/nginx/nginx.conf.rpmsave

  sudo yum install -y --disablerepo=* ${CUBE_TMP}/cube/rpm/8.5/Cube/nginx/*

  sudo sed -i -r "s/listen       80/listen       3777/" /etc/nginx/nginx.conf
  sudo sed -i -r "s/listen       \[\:\:\]\:80/listen       \[\:\:\]\:3777/" /etc/nginx/nginx.conf
  sudo sed -i 's|root         /usr/share/nginx/html|root         '${CUBE_EXEC}'/private_rpm|g' /etc/nginx/nginx.conf
  sudo systemctl restart nginx
}

### Incloud ENV File ###
source ./cube_env

CURRENT_PATH=`pwd`


if [ "${OS_TYPE}" == "centos" ]; then
  ### Create Task Tmp directroy ###
  sudo mkdir -p ${CUBE_TMP}/cube/temp

  echo "### Package File unzip ###"
  sudo tar xvfz ${CURRENT_PATH}/cube.tar.gz -C ${CUBE_TMP}/
  sudo mv ${CUBE_TMP}/temp/acornsoft/cube/* ${CUBE_TMP}/cube/
  sudo rm -rf ${CUBE_TMP}/temp

  echo "It's installing on ${OS_TYPE}"
  centos
elif [ "${OS_TYPE}" == "ubuntu" ]; then
  ### Create Task Tmp directroy ###
  sudo mkdir -p ${CUBE_TMP}/cube/temp

  echo "### Package File unzip ###"
  sudo tar xvfz ${CURRENT_PATH}/cube.tar.gz -C ${CUBE_TMP}/
  sudo mv ${CUBE_TMP}/temp/acornsoft/cube/* ${CUBE_TMP}/cube/
  sudo rm -rf ${CUBE_TMP}/temp

  echo "It's installing on ${OS_TYPE}"
  ubuntu
  sleep 5
elif [ "${OS_TYPE}" == "rocky" ]; then
  ### Create Task Tmp directroy ###
  sudo mkdir -p ${CUBE_TMP}/cube/temp

  echo "### Package File unzip ###"
  sudo tar xvfz ${CURRENT_PATH}/cube.tar.gz -C ${CUBE_TMP}/
  sudo mv ${CUBE_TMP}/temp/acornsoft/cube/* ${CUBE_TMP}/cube/
  sudo rm -rf ${CUBE_TMP}/temp

  echo "It's installing on ${OS_TYPE}"
  rocky
  sleep 5
else
  echo "Please, Check your OS"
  exit 0
fi
