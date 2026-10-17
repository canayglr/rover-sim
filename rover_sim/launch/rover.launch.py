"""wildthumper (lidarsız) için robot_state_publisher + Gazebo<->ROS köprüsü.

Not: Gazebo dünyası ve SITL burada başlatılmaz (gazebo.launch.py ve sitl.launch.py).
"""
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, RegisterEventHandler
from launch.conditions import IfCondition
from launch.event_handlers import OnProcessStart
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

ROVER_SIM = os.environ.get("ROVER_SIM_DIR", os.path.expanduser("~/rover_sim"))


def generate_launch_description():
    pkg_models = get_package_share_directory("ardupilot_sitl_models")

    # sdformat_urdf, kaynakları GZ_SIM_RESOURCE_PATH yerine SDF_PATH ile arar.
    if "GZ_SIM_RESOURCE_PATH" in os.environ:
        gz_path = os.environ["GZ_SIM_RESOURCE_PATH"]
        if "SDF_PATH" in os.environ:
            os.environ["SDF_PATH"] = os.environ["SDF_PATH"] + ":" + gz_path
        else:
            os.environ["SDF_PATH"] = gz_path

    # wildthumper (LİDARSIZ) modeli; wildthumper_with_lidar KULLANILMAZ.
    sdf_file = os.path.join(pkg_models, "models", "wildthumper", "model.sdf")
    with open(sdf_file, "r") as f:
        robot_desc = f.read()
    # robot_state_publisher (sdformat_urdf) model:// yerine package:// ister.
    robot_desc = robot_desc.replace(
        "model://wildthumper", "package://ardupilot_sitl_models/models/wildthumper"
    )

    # /tf ve /tf_static yayını.
    robot_state_publisher = Node(
        package="robot_state_publisher",
        executable="robot_state_publisher",
        name="robot_state_publisher",
        output="both",
        parameters=[{"robot_description": robot_desc}, {"frame_prefix": ""}],
    )

    # Gazebo <-> ROS köprüsü.
    bridge = Node(
        package="ros_gz_bridge",
        executable="parameter_bridge",
        parameters=[
            {
                "config_file": os.path.join(ROVER_SIM, "config", "bridge.yaml"),
                "qos_overrides./tf_static.publisher.durability": "transient_local",
            }
        ],
        output="screen",
    )

    # Gazebo yalnızca odom -> base_link yayınlıyorsa /gz/tf'yi /tf'ye aktar.
    topic_tools_tf = Node(
        package="topic_tools",
        executable="relay",
        arguments=["/gz/tf", "/tf"],
        output="screen",
        respawn=False,
        condition=IfCondition(LaunchConfiguration("use_gz_tf")),
    )

    return LaunchDescription(
        [
            DeclareLaunchArgument("use_gz_tf", default_value="true", description="Gazebo TF kullan."),
            robot_state_publisher,
            bridge,
            RegisterEventHandler(OnProcessStart(target_action=bridge, on_start=[topic_tools_tf])),
        ]
    )
