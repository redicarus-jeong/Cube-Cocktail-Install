#!/bin/bash

echo ""
echo "!! Generate Loki-ca CA certificate !!"

if [ ! -d "ca" ]; then
  mkdir ca
fi

PORT_FILE_NAME=ca/PORT.id
if [[ -z "${PORT_START_NUM}" ]]; then
  PORT_START_NUM=30100
fi

if [[ ! -f "ca/loki-ca.crt" ]]; then
  echo "loki-ca 인증서를 생성합니다."
  # Loki CA
  openssl req -x509 -new -nodes -keyout ca/loki-ca.key -out ca/loki-ca.crt -days 3650 -subj "/CN=loki-ca"
  touch $PORT_FILE_NAME
  echo $PORT_START_NUM > $PORT_FILE_NAME
  next=$(($PORT_START_NUM + 1))
  echo "Next Port NUMBER is $next"
else
  echo "기존 인증서를 사용합니다."
  num=`cat ${PORT_FILE_NAME}`
  next=$(($num + 1))
  echo "Next Port NUMBER is $next"
fi
echo ""