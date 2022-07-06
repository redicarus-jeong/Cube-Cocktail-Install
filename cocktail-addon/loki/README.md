# Grafana Loki(Cocktail-Distributed-log) Cert Manager

## Overview
이 스크립트로 로키용 CA인증서 및 서버 인증서, 클라이언트 인증서를 생성가능합니다.
서버 인증서를 이용하여 (+CA인증서) Loki 서버를 설치 합니다.
Loki 서버와 함께 cocktail log api 서버도 같이 설치 되며 클라이언트 인증서를 입력 합니다.
클라이언트 인증서를 이용하여 Cocktail-Promtail을 설치 합니다.

```
├── loki
│   ├── clear.sh (인증서 초기화)
│   ├── generate_ca.sh (ca인증서 생성하기 - generate에서 호출함)
│   ├── generate.sh (인증서 생성, values.yaml 생성)
│   ├── info.sh (애드온 설치를 위한 정보 조회)
│   ├── ca
│   │   ├── PORT.id (현재 노드포트 ID를 기록)
│   │   ├── loki-ca.crt
│   │   ├── loki-ca.key
│   ├── [platform_id]
│   │   ├── INFO
│   │   ├── loki-client.crt
│   │   ├── loki-client.key
│   │   ├── loki-server.crt
│   │   ├── loki-server.key
│   │   ├── values.yaml
```

## How to use
### 설치용 인증서 생성하기 (by 플랫폼)
```
./generate.sh [PLATFORM_ID] [IP ADDR]
```
loki-ca(if not exists), loki-server, loki-client 인증서를 생성합니다.
NODEPORT 정보는 기준점으로 부터 1씩 증가하며 자동 할당 됩니다.
* values.yaml 수정사항
> - registry 수정 : global.defaultImageRegistry
> - openshift 사용: global.openshift.enabled

### 인증서 정보 확인 (플랫폼)
```
./info.sh [PLATFORM_ID]
```
플랫폼별 LOKI 설치를 위한 인증서 정보를 Print 합니다.
Promtail Addon 설치 시 참고 할 수 있습니다.

### 인증서 제거 (by 플랫폼)
```
./clear.sh [PLATFORM_ID]
```
설치된 플랫폼 인증서를 제거합니다.