#!/bin/bash
# Container'ı arka planda başlatır ve X11 erişimi verir.
# GPU'suz makine için: COMPOSE_FILE=docker-compose.nogpu.yml ./baslat.sh
cd "$(dirname "$(readlink -f "$0")")" || exit 1
xhost +local: >/dev/null 2>&1 || echo "Uyarı: xhost çalışmadı (Gazebo penceresi açılmayabilir). 'sudo apt install x11-xserver-utils'"
docker compose up -d || exit 1
echo "rover_sim çalışıyor. Sırayla: ./sitl.sh, ./gazebo.sh, ./mavproxy.sh (ayrı terminallerde)"
