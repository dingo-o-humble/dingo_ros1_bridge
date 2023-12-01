FROM osrf/ros:humble-desktop

# Taken from https://github.com/TommyChangUMD/ros-humble-ros1-bridge-builder

# How to build this docker image:
#  docker build . -t ros-humble-ros1-bridge-builder
#
# How to build ros-humble-ros1-bridge:
#  # 0.) Start from the ROS 2 Humble system, build a "ros-humble-ros1-bridge/" ROS2 package:
#  docker run --rm ros-humble-ros1-bridge-builder | tar xvzf -
#
# How to use ros-humble-ros1-bridge:
#  # 1.) First start a ROS1 Noetic docker and bring up a GUI terminal, something like:
#  rocker --x11 --user --home --privileged \
#         --volume /dev/shm /dev/shm --network=host -- osrf/ros:noetic-desktop \
#         'bash -c "sudo apt update; sudo apt install -y tilix; tilix"'
#
#  # 2.) Then, start "roscore" inside the ROS1 docker
#  source /opt/ros/noetic/setup.bash
#  roscore
#
#  # 3.) Now, from the ROS2 Humble system, start the ros1 bridge node.
#  source /opt/ros/humble/setup.bash
#  source ros-humble-ros1-bridge/install/local_setup.bash
#  ros2 run ros1_bridge dynamic_bridge
#
#  # 3.) Back to the ROS1 Noetic docker container, run in another terminal tab:
#  source /opt/ros/noetic/setup.bash
#  rosrun rospy_tutorials talker
#
#  # 4.) Finally, from the ROS2 Humble system:
#  source /opt/ros/humble/setup.bash
#  ros2 run demo_nodes_cpp listener
#

# Make sure we are using bash and catching errors
SHELL ["/bin/bash", "-o", "pipefail", "-o", "errexit", "-c"]

# 1.) Temporarily remove ROS2 apt repository
RUN mv /etc/apt/sources.list.d/ros2-latest.list /root/
RUN apt update

# 2.) comment out the catkin conflict
RUN sed  -i -e 's|^Conflicts: catkin|#Conflicts: catkin|' /var/lib/dpkg/status
RUN apt install -f

# 3.) force install these packages
RUN apt download python3-catkin-pkg
RUN apt download python3-rospkg
RUN apt download python3-rosdistro
RUN dpkg --force-overwrite -i python3-catkin-pkg*.deb
RUN dpkg --force-overwrite -i python3-rospkg*.deb
RUN dpkg --force-overwrite -i python3-rosdistro*.deb
RUN apt install -f

# 4.) Install ROS1 stuff
# see https://packages.ubuntu.com/jammy/ros-core-dev
RUN apt -y install ros-core-dev

# 5.) Restore the ROS2 apt repos (optional)
RUN mv /root/ros2-latest.list /etc/apt/sources.list.d/
RUN apt update

# 5.1) Add additional ROS1 ros_tutorials messages and services
RUN mkdir -p ros1_msgs/src && cd ros1_msgs/src && \
    git clone https://github.com/ros/ros_tutorials.git -b noetic-devel && \
    git clone https://github.com/dingo-o-humble/dingo && \
    cd dingo && \
    git checkout 06cdeee63212374608d0add4a780f49fca5d6ecc && \
    cd ../.. && \
    unset ROS_DISTRO && \
    time colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release

# 6.) Compile ros1_bridge
# ref: https://github.com/ros2/ros1_bridge/issues/391
RUN source ros1_msgs/install/local_setup.bash && \
    source /opt/ros/humble/setup.bash  && \
    mkdir -p /ros-humble-ros1-bridge/src && \
    cd /ros-humble-ros1-bridge/src && \
    git clone https://github.com/dingo-o-humble/dingo &&\
    git clone https://github.com/dingo-o-humble/dingo_ros1_bridge &&\
    cd .. && \
    time colcon build --event-handlers console_direct+ --cmake-args -DCMAKE_BUILD_TYPE=Release && \
    source install/setup.bash && \
    cd src && \
    git clone https://github.com/ros2/ros1_bridge &&\
    cd ros1_bridge/ && \
    git checkout b9f1739 && \
    cd ../.. && \
    echo "Please wait...  it takes about 10 minutes to build ros1_bridge" && \
    time colcon build --event-handlers console_direct+ --cmake-args -DCMAKE_BUILD_TYPE=Release

# 7.) Other ROS dependencies
RUN apt install -y ros-humble-xacro ros-humble-robot-localization

# 8.) Clean up
RUN apt -y clean all; apt -y update

# 9.) Pack all ROS1 dependent libraries
RUN ROS1_LIBS="libxmlrpcpp.so"; \
    ROS1_LIBS="$ROS1_LIBS librostime.so"; \
    ROS1_LIBS="$ROS1_LIBS libroscpp.so"; \
    ROS1_LIBS="$ROS1_LIBS libroscpp_serialization.so"; \
    ROS1_LIBS="$ROS1_LIBS librosconsole.so"; \
    ROS1_LIBS="$ROS1_LIBS librosconsole_log4cxx.so"; \
    ROS1_LIBS="$ROS1_LIBS librosconsole_backend_interface.so"; \
    ROS1_LIBS="$ROS1_LIBS liblog4cxx.so"; \
    ROS1_LIBS="$ROS1_LIBS libcpp_common.so"; \
    ROS1_LIBS="$ROS1_LIBS libb64.so"; \
    ROS1_LIBS="$ROS1_LIBS libaprutil-1.so"; \
    ROS1_LIBS="$ROS1_LIBS libapr-1.so"; \
    cd /ros-humble-ros1-bridge/install/ros1_bridge/lib; \
    for soFile in $ROS1_LIBS; do \
        soFilePath=$(ldd libros1_bridge.so | grep $soFile | awk '{print $3;}'); \
        cp $soFilePath ./; \
    done

# 10.) Spit out ros1_bridge tarball by default when no command is given
# RUN tar czf /ros-humble-ros1-bridge.tgz \
#     --exclude '*/build/*' --exclude '*/src/*' /ros-humble-ros1-bridge 

RUN echo '#!/bin/bash' > /launch.sh && \
    echo 'export ROS_DOMAIN_ID=112' >> /launch.sh && \
    echo 'source /opt/ros/humble/setup.bash' >> /launch.sh && \
    echo 'source /ros-humble-ros1-bridge/install/local_setup.bash' >> /launch.sh && \
    echo 'ros2 launch dingo_ros1_bridge robot_launch.py' >> /launch.sh && \
	chmod +x /launch.sh
ENTRYPOINT ["/launch.sh"]
# CMD cat /ros-humble-ros1-bridge.tgz
