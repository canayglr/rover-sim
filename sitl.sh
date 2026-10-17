#!/bin/bash
# Terminal 1: SITL + DDS ajanı + MAVProxy çıkışları (container içinde).
exec docker exec -it rover_sim bash -ic '~/rover_sim/run_sitl.sh "$@"' _ "$@"
