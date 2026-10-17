#!/bin/bash
# Terminal 2: Gazebo + rover + ROS köprüsü. Argümanlar geçirilir, örn: ./gazebo.sh gui:=false
exec docker exec -it rover_sim bash -ic '~/rover_sim/run_gazebo.sh "$@"' _ "$@"
