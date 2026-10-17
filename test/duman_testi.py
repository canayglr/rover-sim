#!/usr/bin/env python3
"""Duman testi (container içinde, ROS ortamı source edilmiş olarak çalışır).

SITL + Gazebo (gui:=false) zaten çalışıyor olmalı (duman_testi.sh başlatır).
Kontroller:
  (a) açılışta ilk 5 sn x kayması < 0.05 m   (ArduPilotPlugin PWM=0 yaması)
  (b) 10 sn gaz 1700 ile en az 1 m ileri
  (c) |roll| < 20 derece (takla yok)
Çıkış kodu: 0 = GEÇTİ, 1 = KALDI.
"""
import math
import sys
import time

import rclpy
from nav_msgs.msg import Odometry
from pymavlink import mavutil
from rclpy.node import Node

MAV_BAGLANTI = "udpin:0.0.0.0:14551"   # MAVProxy'nin ikinci çıkışı (14550 kullanıcı konsolu için boş kalır)
BEKLEME_SN = 5.0
SURUS_SN = 10.0
MAX_KAYMA = 0.05
MIN_ILERI = 1.0
MAX_ROLL_DERECE = 20.0

durum = {}


def odom_cb(o):
    p, q = o.pose.pose.position, o.pose.pose.orientation
    roll = math.atan2(2 * (q.w * q.x + q.y * q.z), 1 - 2 * (q.x * q.x + q.y * q.y))
    durum.update(x=p.x, y=p.y, roll=math.degrees(roll), t=time.time())


def don(node, sn):
    bitis = time.time() + sn
    while time.time() < bitis:
        rclpy.spin_once(node, timeout_sec=0.02)


def main():
    rclpy.init()
    node = Node("duman_testi")
    node.create_subscription(Odometry, "/odometry", odom_cb, 20)

    print("Odometri bekleniyor (/odometry) ...", flush=True)
    bas = time.time()
    while "x" not in durum and time.time() - bas < 120:
        rclpy.spin_once(node, timeout_sec=0.1)
    if "x" not in durum:
        print("KALDI: /odometry gelmedi (Gazebo/köprü çalışmıyor?)")
        return 1

    # (a) arm etmeden 5 sn bekle; PWM0 yaması yoksa rover geri kayar.
    x0, y0 = durum["x"], durum["y"]
    maks_roll = abs(durum["roll"])
    print("Başlangıç: x=%.3f y=%.3f; %.0f sn bekleniyor ..." % (x0, y0, BEKLEME_SN), flush=True)
    bitis = time.time() + BEKLEME_SN
    maks_kayma = 0.0
    while time.time() < bitis:
        rclpy.spin_once(node, timeout_sec=0.02)
        maks_kayma = max(maks_kayma, math.hypot(durum["x"] - x0, durum["y"] - y0))
    kayma = maks_kayma

    # MAVLink: bağlan, ön kontrolleri atla, MANUAL, arm.
    print("MAVLink bağlanıyor: %s" % MAV_BAGLANTI, flush=True)
    m = mavutil.mavlink_connection(MAV_BAGLANTI)
    if m.wait_heartbeat(timeout=90) is None:
        print("KALDI: MAVLink heartbeat yok")
        return 1
    m.mav.param_set_send(m.target_system, m.target_component, b"ARMING_SKIPCHK", -1,
                         mavutil.mavlink.MAV_PARAM_TYPE_INT32)
    don(node, 1)
    m.set_mode_apm("MANUAL")
    don(node, 1)
    for _ in range(8):  # arm bazen ilk denemede reddedilir
        m.arducopter_arm()
        don(node, 1)
        m.recv_match(type="HEARTBEAT", blocking=True, timeout=2)
        if m.motors_armed():
            break
    if not m.motors_armed():
        print("KALDI: arm edilemedi")
        return 1
    print("MANUAL + armed", flush=True)

    # (b)/(c) 10 sn gaz 1700, direksiyon 1500.
    sx, sy = durum["x"], durum["y"]
    bitis = time.time() + SURUS_SN
    son = 0.0
    while time.time() < bitis:
        if time.time() - son >= 0.1:
            m.mav.rc_channels_override_send(m.target_system, m.target_component,
                                            1500, 0, 1700, 0, 0, 0, 0, 0)
            son = time.time()
        rclpy.spin_once(node, timeout_sec=0.02)
        maks_roll = max(maks_roll, abs(durum["roll"]))
    ileri = durum["x"] - sx
    toplam = math.hypot(durum["x"] - sx, durum["y"] - sy)
    # Durdur ve override'ı bırak.
    for _ in range(5):
        m.mav.rc_channels_override_send(m.target_system, m.target_component,
                                        1500, 0, 1500, 0, 0, 0, 0, 0)
        don(node, 0.1)

    a = kayma < MAX_KAYMA
    b = ileri >= MIN_ILERI
    c = maks_roll < MAX_ROLL_DERECE
    print("(a) açılış kayması   : %.4f m (sınır < %.2f)  -> %s" % (kayma, MAX_KAYMA, "GEÇTİ" if a else "KALDI"))
    print("(b) ileri ilerleme   : %.2f m x, %.2f m toplam (sınır >= %.1f x) -> %s"
          % (ileri, toplam, MIN_ILERI, "GEÇTİ" if b else "KALDI"))
    print("(c) azami |roll|     : %.2f derece (sınır < %.0f) -> %s" % (maks_roll, MAX_ROLL_DERECE, "GEÇTİ" if c else "KALDI"))
    ok = a and b and c
    print("SONUÇ: %s" % ("GEÇTİ" if ok else "KALDI"))
    return 0 if ok else 1


if __name__ == "__main__":
    try:
        kod = main()
    finally:
        rclpy.shutdown()
    sys.exit(kod)
