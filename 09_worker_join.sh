#!/bin/bash

### Incloud ENV File ###
source ./cube_env

echo "This Server Kubernetes ${HOSTNAME}"
echo ""
echo "################################################"
echo "### ${HOSTNAME} kubernetes Server JOIN START ###"
echo "################################################"
echo ""
sleep 2

echo ""
echo "############################################################"
echo "### 00 ${HOSTNAME} kubernetes Server PACKAGE UNZIP START ###"
echo "############################################################"
echo ""
sleep 1

sh ./${OS_TYPE}/00_unzip_cubefile.sh
sleep 5

echo ""
echo "#############################################################"
echo "### 08 ${HOSTNAME} kubernetes Server CUBE BOOTSTRAP START ###"
echo "#############################################################"
echo ""
sleep 1

sh ./${OS_TYPE}/08_cube_install.sh
sleep 5

echo ""
echo "############################################"
echo "### Plz User Master Node execute command ###"
echo "############################################"
echo "Command is"
echo ""
echo "\"kubeadm token create --print-join-command\""
echo ""
echo "Good Luck Your Kubernetes Cluster"
echo ""

echo "#########################################"
echo "### 09 ${HOSTNAME} haproxy static pod ###"
echo "#########################################"
sh ./${OS_TYPE}/09_haproxy_static_pod.sh
sleep 5