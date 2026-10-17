#!/bin/bash
# Duman testi: GUI'siz SITL + Gazebo başlatır, duman_testi.py'yi koşar, her şeyi durdurur.
# Container İÇİNDE çalıştırılır:
#   docker exec -it rover_sim bash ~/test/duman_testi.sh [rover_pist|autorace]
# Dünya argümanı verilmezse rover_pist. Günlükler: /tmp/duman_testi/<dünya>/.
# Çıkış kodu: 0 = GEÇTİ, 1 = KALDI.
ROVER_SIM="${ROVER_SIM_DIR:-$HOME/rover_sim}"
TEST_PY="$(dirname "$(readlink -f "$0")")/duman_testi.py"
DUNYA="${1:-rover_pist}"
case "$DUNYA" in rover_pist|autorace) ;; *) echo "Bilinmeyen dünya: $DUNYA (rover_pist|autorace)"; exit 2 ;; esac
LOG=/tmp/duman_testi/$DUNYA
mkdir -p "$LOG"

source /opt/ros/humble/setup.bash
source ~/ros2_ws/install/setup.bash
export GZ_VERSION=harmonic

temizle() { "$ROVER_SIM/stop.sh" >/dev/null 2>&1; }
trap temizle EXIT

temizle
# Temiz parametre: eeprom.bin geçici dizinde (önceki oturumun parametreleri sızmasın)
CALISMA=$(mktemp -d /tmp/duman_sitl.XXXXXX)
cd "$CALISMA"

setsid nohup "$ROVER_SIM/run_sitl.sh" > "$LOG/sitl.log" 2>&1 < /dev/null &
sleep 3
setsid nohup "$ROVER_SIM/run_gazebo.sh" gui:=false rviz:=false world:="$DUNYA" > "$LOG/gazebo.log" 2>&1 < /dev/null &

echo "SITL + Gazebo başlatıldı (dünya: $DUNYA, günlükler: $LOG). Test başlıyor ..."
python3 "$TEST_PY"
KOD=$?
echo "Test çıkış kodu: $KOD"
exit $KOD
