# git URL : https://github.com/redicarus-jeong/cube-cocktail-install.git

# Cube and Cocktail PKG Install & setup
### 1. OS Repository File = CentOS-7.9_PrivateRepo.tar.gz
### 2. Harbor data File = cube_harbor.tgz
### 3. Harbor Install file(v1.10.6) = harbor-offline-install-v1.10.6.tgz
### 4. cube binary file = cube_bin-etcd.tgz.gz

## Cube-5.2.3 & Cocktail-4.6.6 Install Flow
    1. Hostname 및 IP 수정
    2. cocktail user 생성 및 sudo 권한 활당
    3. Private PKG Repository & Container Image Registry 구성
    4. 환경변수 파일 작성(수정)
    5. Master01에만 cube-5.2.3 설치
    6. Master01에서 생성한 인증서(ca)를 다른 master에 복사
    7. Master0X에 cube-5.2.3 설치(Preinstall, etcd)
    8. 모든 Master에 Cube-5.2.3 설치 ( kubeadm )
    9. Work-Node에서 Master01로 join


