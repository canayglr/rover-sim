#!/bin/bash
# Ön kontroller + Docker imajını derler. Eksik bir şey varsa ne yapılacağını söyleyip çıkar.
# Kullanım: ./kurulum.sh
cd "$(dirname "$(readlink -f "$0")")" || exit 1

HATA=0
hata() { echo "[EKSİK] $*"; HATA=1; }
tamam() { echo "[TAMAM] $*"; }

# 1) Docker
if command -v docker >/dev/null 2>&1; then tamam "docker: $(docker --version)"
else hata "docker yok. Kurulum: https://docs.docker.com/engine/install/ubuntu/"; fi

# 2) docker compose v2
if docker compose version >/dev/null 2>&1; then tamam "docker compose: $(docker compose version --short)"
else hata "'docker compose' (v2) yok. 'sudo apt install docker-compose-plugin' (Docker deposundan)."; fi

# 3) Kullanıcı docker grubunda mı / daemon erişimi
if docker info >/dev/null 2>&1; then tamam "docker daemon erişimi var"
else hata "docker daemon'a erişilemiyor. 'sudo usermod -aG docker \$USER' sonra oturumu kapatıp açın (ya da 'newgrp docker')."; fi

# 4) NVIDIA sürücü
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  tamam "NVIDIA sürücü: $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | head -1)"
else hata "nvidia-smi çalışmıyor. NVIDIA sürücüsünü kurun ('sudo ubuntu-drivers autoinstall' ve yeniden başlatın). GPU yoksa docker-compose.nogpu.yml kullanın."; fi

# 5) NVIDIA Container Toolkit
if command -v nvidia-ctk >/dev/null 2>&1; then
  tamam "NVIDIA Container Toolkit: $(nvidia-ctk --version 2>&1 | head -1)"
  if docker info 2>/dev/null | grep -qiE 'nvidia|cdi'; then tamam "docker nvidia runtime/CDI görünüyor"
  else hata "docker nvidia runtime/CDI yok. 'sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker'"; fi
else hata "nvidia-ctk yok. NVIDIA Container Toolkit kurun (README.md 'Gereksinimler')."; fi

# 6) Boş disk >= 15 GB (önerilen 20 GB): temel imaj 4,8 + Gazebo 2,9 + derleme zirvesi ~6 GB (docker'ın veri dizini)
DIZIN=/var/lib/docker; [ -d "$DIZIN" ] || DIZIN=/
BOS_GB=$(df -BG --output=avail "$DIZIN" 2>/dev/null | tail -1 | tr -dc '0-9')
if [ -n "$BOS_GB" ] && [ "$BOS_GB" -ge 15 ]; then tamam "boş disk: ${BOS_GB} GB ($DIZIN)"; [ "$BOS_GB" -lt 20 ] && echo "  Uyarı: 20 GB altı, derleme sınırda kalabilir."
else hata "boş disk yetersiz: ${BOS_GB:-?} GB (en az 15 GB gerekir, 20 GB önerilir, $DIZIN)."; fi

# 7) DISPLAY
if [ -n "$DISPLAY" ]; then tamam "DISPLAY=$DISPLAY"
else hata "DISPLAY boş. Grafik oturumunda bir terminalden çalıştırın (SSH ise 'ssh -X' veya yerel oturum)."; fi

if [ "$HATA" -ne 0 ]; then
  echo; echo "Yukarıdaki eksikleri giderip tekrar çalıştırın."; exit 1
fi

echo; echo "Ön kontroller tamam. İmaj derleniyor (ilk derleme ~25-35 dk, hızlı makinede ölçüldü; yavaş ağda daha uzun) ..."
docker compose build || { echo "Derleme BAŞARISIZ."; exit 1; }
echo "Bitti. Sonraki adım: ./baslat.sh"
