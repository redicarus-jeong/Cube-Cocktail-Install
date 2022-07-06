#!/bin/bash

### etcd process Check
ETCD_PROCESS=`pgrep etcd`

if [ -z ${ETCD_PROCESS} ]; then
  echo "NOT Running ETCD Process, Check your etcd service"
  exit 0
else
  echo "ETCD Process OK, etcd process id = ${ETCD_PROCESS}"
fi

### Check ETCD ionice value
ETCD_IONICE_VALUE=$( ( sudo ionice -p `pgrep etcd` | awk '{print $3}') )

### IONICE exec Command
if [ $ETCD_IONICE_VALUE -eq $ETCD_IONICE_VALUE ] 2>/dev/null ; then
  if [ ${ETCD_IONICE_VALUE} != 0 ]; then
    echo "PID ionice not 0, ionice commnad execute"
    sudo ionice -c2 -n0 -p `pgrep etcd`
  else
    exit 0
  fi
else
  exit 0
fi
