#!/bin/bash

image_name="ros1_bridge:latest"
network_device="wlp2s0"
container_name="ros1_bridge_container"

# Source the ROS setup file
source /opt/ros/noetic/setup.bash

# Function to load ROS parameters from file
load_params() {
    rosparam load /home/administrator/bridge.yaml
}

# Continuously attempt to load ROS parameters and manage container & network states
while true; do
    # Attempt to load parameters
    load_params

    # Check if loading parameters was successful
    if [ $? -eq 0 ]; then
        echo "ROS parameters loaded successfully."

        # Additional delay if needed after successful parameter loading
        sleep 5

        # Manage Docker container and network states continuously
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
                echo "Disconnected. Stopping container if running."
                # Disconnected: Check if container is running
                if [ "$(docker ps -q -f name=$container_name)" ]; then
                    # Stop and remove the container if it's running
                    docker stop $container_name
                    docker rm $container_name
                fi
                break  # Break out of the inner loop
            fi

            # Wait for 2 seconds before checking network state again
            sleep 2
        done
    else
        echo "Failed to load ROS parameters. Retrying in 5 seconds..."
        sleep 5
    fi
done
