#!/bin/bash
# Container içinde: eski Gazebo'yu temizle, sonra Gazebo + rover + ROS köprüsünü başlat.
# Örnek: run_gazebo.sh gui:=false rviz:=true
~/rover_sim/stop.sh gaz
source ~/ros2_ws/install/setup.bash
export GZ_VERSION=harmonic
exec ros2 launch ~/rover_sim/launch/gazebo.launch.py "$@"
