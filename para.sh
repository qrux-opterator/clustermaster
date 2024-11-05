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
    cmd="$DIR_PATH/node-$version-$os-$architecture --core=0 --signature-check=false --network=1"
    echo "DEBUG: Starting parent node with command: $cmd"
    $cmd &
    parent_pid=$!
    echo "Node parent ID: $parent_pid"

    # Wait for 2 seconds
    sleep 2
    echo "Starting worker nodes..."

    # Start worker nodes from core 1 to maxCores - 1
    for core_num in $(seq 1 $((maxCores - 1))); do
        cmd="$DIR_PATH/node-$version-$os-$architecture --core=$core_num --signature-check=false --network=1 --parent-process=$parent_pid"
        echo "DEBUG: Deploying core $core_num with command: $cmd"
        $cmd &
        worker_pids[$core_num]=$!
    done
else
    echo "Starting worker nodes on slave machine..."

    # Start worker nodes from startingCore + 1 to startingCore + maxCores
    for core_num in $(seq $((startingCore + 1)) $((startingCore + maxCores))); do
        cmd="$DIR_PATH/node-$version-$os-$architecture --core=$core_num --signature-check=false --network=1"
        echo "DEBUG: Deploying core $core_num with command: $cmd"
        $cmd &
        worker_pids[$core_num]=$!
    done
fi

# Function to check if all workers are running
check_workers() {
    for core_num in "${!worker_pids[@]}"; do
        pid=${worker_pids[$core_num]}
        if ! kill -0 $pid 2>/dev/null; then
            echo "WORKER FAILED: Core $core_num"
            # TODO: Future enhancement to restart the worker
        fi
    done
}

# Keep the script running and check workers every 3 minutes
while true; do
    sleep 180  # Sleep for 3 minutes
    check_workers
done
