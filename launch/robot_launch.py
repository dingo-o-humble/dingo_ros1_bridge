#!/usr/bin/env python

import os
from launch import LaunchDescription
from launch.substitutions import Command
from launch.actions import ExecuteProcess
from launch_ros.actions import Node
from ament_index_python.packages import get_package_share_directory


def generate_launch_description():
    this_share_directory = get_package_share_directory("dingo_description")
    dingo_control_directory = get_package_share_directory("dingo_control")

    ros1_bridge = ExecuteProcess(
        cmd=["ros2", "run", "ros1_bridge", "parameter_bridge"],
        output="screen",
    )

    # Dingo-O
    os.environ["DINGO_OMNI"] = "1"

    xacro_path = os.path.join(this_share_directory, "urdf", "dingo.urdf.xacro")
    robot_description = Command(
        [
            os.path.join(this_share_directory, "env_run"),
            " ",
            os.path.join(this_share_directory, "urdf", "configs", "base"),
            " ",
            "xacro",
            " ",
            xacro_path,
            " ",
            "physical_robot:=",
            "true",
            " ",
            "control_yaml_file:=",
            dingo_control_directory + "/config/control_omni.yaml",
        ]
    )
    robot_state_publisher = Node(
        package="robot_state_publisher",
        executable="robot_state_publisher",
        output="screen",
        parameters=[{"robot_description": robot_description}],
    )

    footprint_publisher = Node(
        package="tf2_ros",
        executable="static_transform_publisher",
        output="screen",
        arguments=["0", "0", "0", "0", "0", "0", "base_link", "base_footprint"],
    )

    ekf_node = Node(
        package="robot_localization",
        executable="ekf_node",
        name="ekf_filter_node",
        output="screen",
        parameters=[
            os.path.join(
                get_package_share_directory("dingo_ros1_bridge"),
                "config",
                "ekf.yaml",
            )
        ],
    )

    return LaunchDescription(
        [
            ros1_bridge,
            robot_state_publisher,
            footprint_publisher,
            ekf_node,
        ]
    )
