"""Gazebo (düz pist) + wildthumper rover + ROS köprüsü (+ isteğe bağlı RViz).

SITL ayrı çalışır: sitl.launch.py (run_sitl.sh).
Argümanlar: gui:=true|false (Gazebo penceresi), rviz:=true|false (varsayılan false),
world:=rover_pist|autorace (varsayılan rover_pist; autorace = TurtleBot3 AutoRace, worlds/autorace/).
İki dünyanın da SDF içindeki adı "rover_pist"tir; bu yüzden config/bridge.yaml ortaktır.
"""
import os
from pathlib import Path

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import (
    AppendEnvironmentVariable,
    DeclareLaunchArgument,
    IncludeLaunchDescription,
    OpaqueFunction,
)
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

ROVER_SIM = os.environ.get("ROVER_SIM_DIR", os.path.expanduser("~/rover_sim"))


DUNYALAR = {
    "rover_pist": "rover_pist.sdf",
    "autorace": "autorace/autorace.sdf",
}


def _gz(context, *args, **kwargs):
    dunya = LaunchConfiguration("world").perform(context)
    if dunya not in DUNYALAR:
        raise RuntimeError("Bilinmeyen world:=%s (seçenekler: %s)" % (dunya, ", ".join(DUNYALAR)))
    world_path = str(Path(ROVER_SIM) / "worlds" / DUNYALAR[dunya])
    pkg_ros_gz_sim = get_package_share_directory("ros_gz_sim")
    gz_launch = str(Path(pkg_ros_gz_sim) / "launch" / "gz_sim.launch.py")
    eylemler = []
    if dunya == "autorace":
        # model://turtlebot3_autorace_2020/... için (sunucu ve GUI aynı ortamı kullanır).
        eylemler.append(
            AppendEnvironmentVariable(
                "GZ_SIM_RESOURCE_PATH", str(Path(ROVER_SIM) / "worlds" / "autorace" / "models")
            )
        )
    eylemler.append(
        IncludeLaunchDescription(
            PythonLaunchDescriptionSource(gz_launch),
            launch_arguments={"gz_args": "-v4 -s -r " + world_path}.items(),
        )
    )
    eylemler.append(
        IncludeLaunchDescription(
            PythonLaunchDescriptionSource(gz_launch),
            launch_arguments={"gz_args": "-v4 -g"}.items(),
            condition=IfCondition(LaunchConfiguration("gui")),
        )
    )
    return eylemler


def generate_launch_description():
    rover = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(ROVER_SIM + "/launch/rover.launch.py")
    )
    rviz = Node(
        package="rviz2",
        executable="rviz2",
        parameters=[{"use_sim_time": True}],
        condition=IfCondition(LaunchConfiguration("rviz")),
    )
    return LaunchDescription(
        [
            DeclareLaunchArgument("rviz", default_value="false", description="RViz aç."),
            DeclareLaunchArgument("gui", default_value="true", description="Gazebo penceresini aç."),
            DeclareLaunchArgument("world", default_value="rover_pist", description="Dünya: rover_pist | autorace."),
            OpaqueFunction(function=_gz),
            rover,
            rviz,
        ]
    )
