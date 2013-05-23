#!/bin/bash
scriptDir="$(cd "$(dirname "$0")" && pwd && cd - 1> /dev/null 2>&1)"
case $1 in
  start)
    echo -n "Starting RRSBT : "
    ruby1.9.1 "${scriptDir}/main.rb" &
    pid=$!
    echo $pid > "${scriptDir}/rrsbt.pid"
    echo "Started"
    exit 0
  ;;
  stop)
    echo -n "Stopping RRSBT : "
    if [ -r "${scriptDir}/rrsbt.pid" ]
    then
      pid=$(cat ${scriptDir}/rrsbt.pid)
      kill -1 $pid 2> /dev/null
      rm "${scriptDir}/rrsbt.pid"
      echo "Stopped"
      exit 0
    else
      echo "Can't stop, no pid found"
      exit 1
    fi
  ;;
  restart)
    echo -n "Restarting RRSBT : "
    if [ -r "${scriptDir}/rrsbt.pid" ]
    then
      pid=$(cat "${scriptDir}/rrsbt.pid")
      kill -1 $pid
      rm "${scriptDir}/rrsbt.pid"
      echo -n "Stopped - "
    fi
    ruby1.9.1 "${scriptDir}/main.rb" &
    pid=$!
    echo $pid > "${scriptDir}/rrsbt.pid"
    echo "Restarted"
    exit 0
  ;;
  *)
  echo "Usage: $0 {start|stop|restart}"
  ;;
esac
