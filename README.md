# git URL : https://github.com/redicarus-jeong/cube-cocktail-install.git

# Cube and Cocktail PKG Install & setup
### 1. OS Repository File = CentOS-7.9_PrivateRepo.tar.gz
### 2. Harbor data File = cube_harbor.tgz
### 3. Harbor Install file(v1.10.6) = harbor-offline-install-v1.10.6.tgz
### 4. cube binary file = cube_bin-etcd.tgz.gz

## Cube Install Flow
### I. Run 01_master_env_init.sh in Master01
### script call list in 01_master_env_init.sh
    1. sh ./${OS_TYPE}/00_unzip_cubefile.sh
    2. sh ./${OS_TYPE}/01_create_openssl.sh
    3. sh ./${OS_TYPE}/02_certificate.sh init 
       ( master01이면 init하고 그렇지 않으면 init 하지 않는다. )
    4. sh ./${OS_TYPE}/03_kubeconfig_create.sh
    5. sh ./${OS_TYPE}/04_audit.sh
    6. sh ./${OS_TYPE}/05_async_kubeadm_pki.sh

먼저 master01이고 $ETCD_MEMBER_COUNT를 찾아 Cube_env에 등록된 master 수와 같으면 "ETCD Bootstrap을 skip하고,
같지 않거나 그외 master은 아래 명령어를 실행한다.

    7. sh ./${OS_TYPE}/06_etcd_bootstrap.sh
    * OS_TYPE 별 실행되는 것이 조금 다르다...!!
    
### II. Run 04.Copy_Certificate.sh 
### III. Run 01_master_env_init.sh in Master02, Master03
