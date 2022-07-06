# Cocktail-Kafka Cert manager

## How to use

### 기본 인증서 생성
---
```
# @IPADDR : 도메인 혹은 IP 주소 (콤마를 이용하여 배열로 입력 가능합니다.)
# @NAMESPACE : 카프카를 설치할 네임스페이스 (통상적으로 칵테일과 같은 네임스페이스를 사용합니다.)
./generate.sh [IPADDR | DOMAIN] [NAMESPACE]
```
Kafka URL : https://[IPADDR]:[30010] \
cocktail 시스템에 설치될 kafka의 인증서와 values.yaml을 생성합니다. \
storage class, advertise Host 등의 정보를 확인 후 설치를 진행하여야 합니다. \
다음 명령으로 설치를 완료할 수 있습니다.
```
# Installation of cocktail-message-queue can be done with the following steps.
# --------------------------------------------------------------------
  helm repo add cube https://regi.acloud.run/chartrepo/cube
  helm repo update
  helm upgrade --install cocktail-mq cube/cocktail-message-queue -f tmp/values.yaml --namespace cocktail-system

```

### 컬렉터용 인증서 파일 생성
---
- 생성한 Collector 인증서를 사용하기 위한 시크릿을 생성합니다.
- * 칵테일을 수동 설치한 경우 별도의 helm 설정 파일이 없기 때문에 이 시크릿을 이용하여 카프카 연동을 처리 할 수 있습니다.
- 칵테일 설치할 때 시크릿 파일의 내용을 참고 할 수 있습니다.
- * 칵테일을 helm 설치하는 경우 필요한 인증서 정보를 tmp/kafka-collector-secret.yaml 파일에서 복사할 수 있습니다.
```
./make_kafka_collector.sh [NAMESPACE]
# example
./make_kafka_collector.sh cocktail-system
```
우선 generate.sh로 인증서가 생성되어 있어야 합니다.

### 카프카 유저 생성
---
Kafka를 사용하여 고객 클러스터의 모니터링 데이터를 중앙에 전달 하기 위해서는 kafka-user가 등록 되어 있어야 합니다. Cocktail을 사용하는 kafka-user는 플랫폼 별로 구분이 됩니다. 따라서 신규 플랫폼 등록을 하게 되면 kafka-user도 같이 생성되어야 합니다.
```
# 설정 파일 생성하기
./add_user.sh [PLATFORM_NAME]

# install
# 예시(관습에 의한)
helm upgrade --install cocktail-mq-user-[PLATFORM_NAME:lowercase] cube/cocktail-message-queue-user \
-f tmp/agent_values.yaml --namespace=cocktail-system
```
> 유저를 설치한 네임스페이스에 “cocktail-mq-user-[PlatformID]” 이름의 시크릿이 생성됩니다.
> monitoring-agent 애드온을 설치할 때 카프카 인증서 정보는 이 시크릿을 이용하면 됩니다.
>
> kubectl get secret -n cocktail-addon cocktail-mq-user-{platformId} -oyaml
>
> Addon의 파라미터로 입력하는 경우 base64 인코딩을 안해도 정상처리 됩니다.  편의를 위해 위 스크립트로 보여지는 base64 인코딩된 값을 그대로 입력 합니다.

### 초기화
---
기 생성된 인증서를 제거하고 새로 설치하려고 할 때 필요합니다. \
내부적으로 tmp 폴더를 이용하는데 폴더 내 모든 파일을 제거하고 다시 .generate.sh 를 수행할 수 있는 환경으로 만듭니다.
```bash
./clear.sh
All authentication files previously in use will be removed.
Are you sure you want to remove it?
y/n: y
Initialized!
```
