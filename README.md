# Dingo - ROS2 Humble with ros1_bridge and Docker

## Installation (On Dingo)

### Install Docker and set it up from https://docs.docker.com/engine/install/ubuntu/

### Build docker image
```
cd
# Change ROS_DOMAIN_ID before building if needed
wget https://github.com/dingo-o-humble/dingo_ros1_bridge/raw/main/Dockerfile

# Takes around 20 minutes
docker build . -t ros1_bridge
```

### Download bridge params and create alias
```
wget https://github.com/dingo-o-humble/dingo_ros1_bridge/raw/main/bridge.yaml
echo '
alias dingo-ros2="rosparam load bridge.yaml && \
sleep 2 && \
docker run -it --net=host ros1_bridge:latest"' >> .bashrc
. .bashrc
```

## Usage

### On Dingo
```
# All accessible topics will be visible on remote computer
dingo-ros2

# To visual Robot in Rviz2, build and source https://github.com/dingo-o-humble/dingo locally.
```

### On Remote computer
```
ros2 run teleop_twist_keyboard teleop_twist_keyboard --ros-args -r /cmd_vel:=/dingo_velocity_controller/cmd_vel
```

## Auto-start (On Dingo)
```
cd
wget https://github.com/dingo-o-humble/dingo_ros1_bridge/raw/main/start_ros1_bridge.sh
chmod +x start_ros1_bridge.sh
```

```
echo '[Unit]
Description=Automatic Start for ROS1 Bridge Script
After=ros.service
Wants=ros.service

[Service]
Type=simple
ExecStart=/home/administrator/start_ros1_bridge.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/ros1_bridge_autostart.service
```
```
sudo systemctl daemon-reload
sudo systemctl enable ros1_bridge_autostart.service
sudo systemctl start ros1_bridge_autostart.service
```
