# AutoRace dünyası: kaynak ve değişiklikler

Bu klasördeki dünya ve modeller **ROBOTIS TurtleBot3 AutoRace 2020** pistinden türetilmiştir.

- Kaynak depo: https://github.com/ROBOTIS-GIT/turtlebot3_simulations (Apache-2.0, `LICENSE` bu klasörde)
- Dal: `feature-gazebo-sim-migration`
- Commit (sabit): `970a3d026d3e86a89c2fba254934e62edaecbcbb` (2025-02-27)
- Alınan dosyalar: `turtlebot3_gazebo/worlds/turtlebot3_autorace_2020.world` ve
  `turtlebot3_gazebo/models/turtlebot3_autorace_2020/{course,traffic_bar,traffic_light,traffic_parking,traffic_tunnel,traffic_stop,traffic_pl_left,traffic_construction,traffic_intersection,traffic_noentry,traffic_right}`.
  Dünyada kullanılmayan `checker` ve `traffic_left` modelleri ve TurtleBot3 robot modelleri alınmadı.
- Not: Bu dalda da AutoRace dünyası hâlâ Gazebo Classic biçimindedir (OGRE `.material`, Classic eklentileri).
  `jazzy`/`main` dallarında yalnızca `.world` dosyası var, modeller yok. Dolayısıyla dönüşüm bu pakette yapılmıştır.

## Yapılan değişiklikler (Gazebo Harmonic / gz sim 8 için)

- Dünya `autorace.sdf` olarak yeniden yazıldı (SDF 1.9). Dünya adı bilerek `rover_pist` (bridge konuları ortak kalsın).
  Fizik/eklentiler (`Physics`, `Sensors`, `UserCommands`, `SceneBroadcaster`, `Imu`, `Magnetometer`, `NavSat`)
  ve `<spherical_coordinates>` (ArduPilot GPS için) `rover_pist.sdf` ile aynıdır.
- OGRE `.material` betikleri kaldırıldı; her doku `<pbr><metal><albedo_map>` olarak bağlandı (metalness 0, roughness 1).
  `Gazebo/Grey` / `Gazebo/FlatBlack` malzemeleri düz `<ambient>/<diffuse>` renklerine çevrildi.
- **Kaldırılan eklentiler:** `libtraffic_light_plugin.so` (trafik ışığı renk döngüsü) ve `libtraffic_bar_plugin.so`
  (bariyer kolu açılıp kapanması). Trafik ışığı sabit **kırmızı**, bariyer kolu sabit durur.
- `<state>`, `<gui>` (Classic kamera), kaldırılan `ode` fizik bloğu ve Classic'e özgü alanlar (`kinematic`, `shader`, `laser_retro` vb.) silindi.
- Tüm işaret/bariyer/engel modelleri `static` yapıldı (rover çarparsa devrilmez/uçmaz); kütlesi 0 olan `Wall_3` atalet hatası
  verdiği için tüm `inertial` blokları kaldırıldı.
- Sürtünme: tüm çarpışma yüzeylerinde `mu=mu2=1.0` (kaynakta zemin `mu=100/mu2=50` idi; rover takla atıyordu).
  Pist zemini sonsuz `plane` yerine 4x4x0.1 m `box` çarpışmasına çevrildi; pistin dışına 12x12 m siyah zemin (`zemin`) eklendi.
- Işık: kaynaktaki güneş ve üç nokta ışık aynen korundu. Işık konumları ve `range` değerleri de ölçeğe dahil edilmiştir.
- **3x ölçek (rover için):** pist 4x4 m -> 12x12 m, şerit ~0,3 m -> ~0,9 m (çizgi eksenleri arası), dış zemin 30x30 m görsel / 36x36 m çarpışma.
  `olcekle.py` orijinal 1x dosyaları (`orijinal/autorace.sdf`, `orijinal/models/.../model.sdf`) okuyup tüm `<pose>` konumlarını (x y z), `<size>`, `<radius>`, `<length>` ve ışık `<range>` değerlerini 3 ile çarpar
  (dönüşler, sürtünme ve dokular değişmez; z de ölçeklendiğinden nesneler zeminde kalır). `autorace.sdf` ve `models/*/model.sdf` üretilmiş çıktıdır, elle düzenlenmez. Rover modeli (wildthumper) ölçeklenmez.
- Rover başlangıç pozu: `(1.5, -5.1, 0.15)`, yaw 0 (1x'teki `(0.5, -1.70)` x3, betikle). Şerit ortasına yakın (doku ölçümüne göre ~0,1 m sağda/solda sapma), kırmızı başlangıç çizgisinin (x~2,7) önünde,
  tünel duvarından ~1,5 m uzakta.
- Dosyalar: `onizleme.png` Xvfb + yazılım render ile alınmış Gazebo GUI görüntüsüdür.
