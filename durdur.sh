#!/bin/bash
# Simülasyon süreçlerini durdurur (container kalır). Tamamen kapatmak için: ./durdur.sh --kapat
cd "$(dirname "$(readlink -f "$0")")" || exit 1
docker exec rover_sim bash -c '~/rover_sim/stop.sh' || echo "container çalışmıyor olabilir"
if [ "$1" = "--kapat" ]; then docker compose down; fi
