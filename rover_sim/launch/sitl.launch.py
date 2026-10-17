"""ArduPilot Rover SITL + micro-ROS DDS ajanı (Gazebo/ROS ayrı: gazebo.launch.py).

Parametre dosyaları sırayla yüklenir (sonraki öncekini ezer):
  rover-skid.parm  -> skid-steer rover varsayılanları (ardupilot_sitl paketi)
  dds_udp.parm     -> DDS/UDP ayarları
  rover_sim.parm   -> bu projenin sim fiziğine göre hız/fren ayarı
"""
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare

ROVER_SIM = os.environ.get("ROVER_SIM_DIR", os.path.expanduser("~/rover_sim"))


def generate_launch_description():
    pkg_ardupilot_sitl = get_package_share_directory("ardupilot_sitl")
    params = ",".join(
        [
            os.path.join(pkg_ardupilot_sitl, "config", "default_params", "rover-skid.parm"),
            os.path.join(pkg_ardupilot_sitl, "config", "default_params", "dds_udp.parm"),
            os.path.join(ROVER_SIM, "config", "rover_sim.parm"),
        ]
    )

    sitl_dds = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            [
                PathJoinSubstitution(
                    [FindPackageShare("ardupilot_sitl"), "launch", "sitl_dds_udp.launch.py"]
                ),
            ]
        ),
        launch_arguments={
            "transport": "udp4",
            "port": "2019",
            "command": "ardurover",
            "synthetic_clock": "True",
            "wipe": "False",
            "model": "json",
            "speedup": "1",
            "slave": "0",
            "instance": "0",
            "defaults": params,
            "sim_address": "127.0.0.1",
            "master": "tcp:127.0.0.1:5760",
            "sitl": "127.0.0.1:5501",
        }.items(),
    )

    return LaunchDescription([sitl_dds])
