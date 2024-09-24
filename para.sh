#!/bin/bash
DIR_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

os=$1
architecture=$2
startingCore=$3
maxCores=$4
pid=$$
version=$5
crashed=0

start_process() {
  pkill node-*
  if [ $startingCore == 0 ]
  then
    $DIR_PATH/node-$version-$os-$architecture &
    pid=$!
  	if [ $crashed == 0 ]
  	then
    	maxCores=$(expr $maxCores - 1)
	fi
  fi

  echo Node parent ID: $pid;
  echo Max Cores: $maxCores;
  echo Starting Core: $startingCore;

  for i in $(seq 1 $maxCores)
  do
    echo Deploying: $(expr $startingCore + $i) data worker with params: --core=$(expr $startingCore + $i) --parent-process=$pid;
    $DIR_PATH/node-$version-$os-$architecture --core=$(expr $startingCore + $i) --parent-process=$pid &
  done
}

is_process_running() {
    ps -p $pid > /dev/null 2>&1
    return $?
}

start_process

while true
do
  if ! is_process_running; then
    echo "Process crashed or stopped. restarting..."
	crashed=$(expr $crashed + 1)
    start_process
  fi
  sleep 440
done
