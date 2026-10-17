#!/bin/bash
# Rover simülasyonuna ait TÜM süreçleri durdurur (container içinde çalıştır).
# Kullanım: stop.sh [sitl|gaz]   (argümansız: hepsi)
# [x] köşeli parantez hilesi: pkill -f kendi komut satırını eşleştirip kendini öldürmesin.
# gz SIGTERM'i yok sayabiliyor -> 2 sn sonra SIGKILL.
kill_all() { for p in "$@"; do pkill -f "$p" 2>/dev/null; done; sleep 2; for p in "$@"; do pkill -9 -f "$p" 2>/dev/null; done; }
sitl_kill() { kill_all "[s]itl.launch.py" "[a]rdurover" "[m]icro_ros_agent" "[m]avproxy"; }
gaz_kill()  { kill_all "[g]azebo.launch.py" "[g]z sim" "[r]uby /usr/bin/gz" "[r]viz2" "[r]obot_state_publisher" "[p]arameter_bridge" "[t]opic_tools"; }
case "$1" in
  sitl) sitl_kill ;;
  gaz)  gaz_kill ;;
  *)    sitl_kill; gaz_kill ;;
esac
# SITL portu (5760 = 0x1680) tamamen boşalana kadar bekle (eski bağlantılar TIME_WAIT'te kalabilir)
if [ "$1" != "gaz" ]; then
  for i in $(seq 1 90); do grep -q ":1680 " /proc/net/tcp || break; sleep 1; done
fi
sleep 1
echo "durduruldu ${1:-hepsi}"
