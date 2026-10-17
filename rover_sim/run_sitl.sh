#!/bin/bash
# Container içinde: eski SITL'i temizle, sonra SITL + DDS ajanını (+ MAVProxy çıkışları) başlat.
~/rover_sim/stop.sh sitl
source ~/ros2_ws/install/setup.bash
export GZ_VERSION=harmonic
exec ros2 launch ~/rover_sim/launch/sitl.launch.py "$@"
