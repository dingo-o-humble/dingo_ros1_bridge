#!/bin/bash

image_name="ros1_bridge:latest"
network_device="wlp2s0"
container_name="ros1_bridge_container"

source /opt/ros/noetic/setup.bash
rosparam load /home/administrator/bridge.yaml

sleep 5

while true; do
    # Check network state
    nmcli -t -f GENERAL.STATE device show $network_device | grep -q "(connected)"

    if [ $? -eq 0 ]; then
        # Connected: Check if container is already running
        if [ ! "$(docker ps -q -f name=$container_name)" ]; then
            # Remove the container if it exists but stopped
            if [ "$(docker ps -aq -f status=exited -f name=$container_name)" ]; then
                docker rm $container_name
            fi
            # Start the container
            docker run -d --net=host --name $container_name $image_name
        fi
    else
        sleep 10
        # Disconnected: Check if container is running
        if [ "$(docker ps -q -f name=$container_name)" ]; then
            # Stop and remove the container if it's running
            docker stop $container_name
            docker rm $container_name
        fi
    fi

    # Wait for 2 seconds before checking again
    sleep 2
done
