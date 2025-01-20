#!/bin/bash

# newpara.sh

# Get the directory of the script
DIR_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)

# Input variables
os=$1
architecture=$2
startingCore=$3
maxCores=$4
version=$5

# Associative array to keep track of worker PIDs
declare -A worker_pids

if [ "$startingCore" -eq 0 ]; then
    # Start parent node with core 0
    cmd="sudo chrt -f 92 $DIR_PATH/node-$version-$os-$architecture --signature-check=false"
    echo "DEBUG: Starting parent node with command: $cmd"
    $cmd &
    parent_pid=$!
    echo "Node parent ID: $parent_pid"

    # Wait for 2 seconds
    sleep 2
    echo -e "\e[1;38;5;214mTHIS NODE RUNS WITH HIGHER PRIORITY THAN USUAL\e[0m"


    # Start worker nodes from core 1 to maxCores - 1
    for core_num in $(seq 1 $((maxCores - 1))); do
        cmd="sudo chrt -f 88 $DIR_PATH/node-$version-$os-$architecture --core=$core_num --parent-process=$parent_pid -signature-check=false"
        echo "DEBUG: Deploying core $core_num with command: $cmd"
        echo -e "\033[1;33mTHIS NODE RUNS WITH HIGHER PRIORITY THAN USUAL\033[0m"

        $cmd &
        worker_pids[$core_num]=$!
    done
else
    echo "Starting worker nodes on slave machine..."

    # Start worker nodes from startingCore + 1 to startingCore + maxCores
    for core_num in $(seq $((startingCore + 1)) $((startingCore + maxCores))); do
        cmd="sudo chrt -f 88 $DIR_PATH/node-$version-$os-$architecture --core=$core_num -signature-check=false"
        echo "DEBUG: Deploying core $core_num with command: $cmd"
        $cmd &
        worker_pids[$core_num]=$!
    done
    echo -e "\033[1;33mTHIS NODE RUNS WITH HIGHER PRIORITY THAN USUAL\033[0m"
fi

# Function to check if all workers are running
check_workers() {
    for core_num in "${!worker_pids[@]}"; do
        pid=${worker_pids[$core_num]}
        if ! kill -0 $pid 2>/dev/null; then
            echo "WORKER FAILED: Core $core_num"
            sleep 5
           # service para restart
           # exit
        fi
    done
}

# Keep the script running and check workers every 3 minutes
while true; do
    sleep 180  # Sleep for 3 minutes
    check_workers
done
