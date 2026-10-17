# AGENT.md: Yapay zekâ ajanı için kurulum ve doğrulama rehberi

Hedef: Ubuntu + NVIDIA GPU üzerinde Docker ile rover simülasyonunu kurmak ve duman testini geçirmek.

## Kesin komut sırası

1. `./kurulum.sh`
   - Beklenen: tüm satırlar `[TAMAM]`, sonunda `docker compose build` (~25-35 dk ölçüldü, imaj 8,3 GB; en az 15 GB, önerilen 20 GB boş disk). Bir `[EKSİK]` varsa DUR, kullanıcıya söyle (sürücü/toolkit kurulumu yönetici onayı ister).
   - Doğrulama: `docker image ls rover_sim` imajı gösterir.
2. `./baslat.sh`
   - Doğrulama: `docker ps --filter name=rover_sim` -> `Up`.
   - Doğrulama (GPU): `docker exec rover_sim nvidia-smi` GPU'yu listeler.
3. Duman testi (GUI gerekmez):
   `docker exec rover_sim bash -c '~/test/duman_testi.sh'`
   - Beklenen son satırlar: `(a) ... GEÇTİ`, `(b) ... GEÇTİ`, `(c) ... GEÇTİ`, `SONUÇ: GEÇTİ`, çıkış kodu 0.
   - Günlükler container içinde `/tmp/duman_testi/{sitl,gazebo}.log`.
   - AutoRace dünyası: `docker exec rover_sim bash -c '~/test/duman_testi.sh autorace'` (aynı beklenen çıktı; günlükler `/tmp/duman_testi/autorace/`). Varsayılan dünya için günlükler `/tmp/duman_testi/rover_pist/`.
   - GUI'siz yükleme denetimi (AutoRace): `docker exec rover_sim bash -c 'source ~/ros2_ws/install/setup.bash; export GZ_VERSION=harmonic GZ_SIM_RESOURCE_PATH=$GZ_SIM_RESOURCE_PATH:~/rover_sim/worlds/autorace/models; timeout 25 gz sim -v4 -s -r ~/rover_sim/worlds/autorace/autorace.sdf 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "\[err\]|unable to find|error"'` -> çıktı boş olmalı (rover modelinden gelen iki `Warning [Utils.cc]` zararsızdır).
4. İnsan kullanımı için: `./sitl.sh`, `./gazebo.sh` (AutoRace: `./gazebo.sh world:=autorace`), `./mavproxy.sh` (üç ayrı terminal), bkz. README.md.
5. Bitirince: `./durdur.sh --kapat`.

## Bilinen tuzaklar

- `pkill -f desen` komutu kendi kabuğunun komut satırını da eşleştirip kendini öldürür. `stop.sh` bu yüzden `[x]` hilesini kullanır (`pkill -f "[a]rdurover"`). Yeni kill komutlarında aynısını yapın.
- `gz sim` SIGTERM'i yok sayabilir; `stop.sh` 2 sn sonra SIGKILL gönderir. Süreç öldü sanmadan `ps` ile doğrulayın.
- SITL TCP 5760 portu eski bağlantılardan TIME_WAIT'te kalabilir; `stop.sh` port boşalana kadar bekler. Başlatmadan önce her zaman `stop.sh` çalışır.
- Parametreler çalışma dizinindeki `eeprom.bin` içinde kalıcıdır (`wipe:=False`). Parametre değiştirdiyseniz etkili olmayabilir; `eeprom.bin` silin. Duman testi bunu geçici dizinde çalıştırarak aşar.
- Dockerfile'da `colcon`/`rosdep` öncesinde `source /opt/ros/humble/setup.bash` AYNI `RUN` içinde olmalıdır (ayrı `RUN source` etkisizdir). Aksi halde ardupilot_gazebo ament olmadan yapılandırılıp kalır.
- PWM0 yaması (`rover_sim/patches/ArduPilotPlugin_pwm0.patch`) yoksa rover açılışta ~0,7 m geri kayar. Yama uygulanamazsa derleme bilerek FAIL eder; commit'i değiştirmeden önce `git apply --check` yapın.
- Zemin sürtünmesi `mu=1.0` kalmalı (`worlds/rover_pist.sdf` ve `worlds/autorace/`); `mu=100` iken rover takla atar.
- AutoRace'te rover başlangıç pozu (`autorace.sdf` sonundaki `include`) tünel duvarından uzak olmalı: (1x ölçekte) x<0.3 iken rover arka ucu `Wall_3`'e temas edip ilk saniyede 35° yana savruldu. Dünya şimdi 3x ölçeklidir ve başlangıç `(1.5, -5.1)`; **`autorace.sdf` ve `models/*/model.sdf` üretilmiş dosyalardır: değişiklik `worlds/autorace/orijinal/` altında yapılıp `python3 worlds/autorace/olcekle.py [ölçek]` ile yeniden üretilir** (rover include'unda yalnızca x,y ölçeklenir). Pozu değiştirirseniz duman testinde (b)'nin yanında `/odometry` y sapmasına bakın.
- Her iki dünyanın SDF adı `rover_pist`tir (bridge konuları `/world/rover_pist/...`); yeni dünya eklerseniz adı aynı tutun ya da bridge'i değiştirin.
- `rover_sim/` klasörü container'a bind mount edilir; launch/parm/dünya değişiklikleri imaj yeniden derlemeden geçerli olur. Yalnızca Dockerfile/yama değişince yeniden derleme gerekir.
- `rover-skid.parm` varsayılanı CRUISE_SPEED 3 m/s'dir; sim rover ~1,39 m/s yapar. `config/rover_sim.parm` bunu ezer.

- ArduPilot waf derlemesi (colcon `ardupilot_sitl`) rosdep ile gelmeyen Python paketleri ister (pexpect, future, lxml, dronecan, empy==3.3.4, ptyprocess). Dockerfile'da pip ile kurulur; `install-prereqs-ubuntu.sh` kullanılmaz. Bu eksikken derleme yalnızca `gmake Error 1` verir; asıl mesaj ('you need to install pexpect') stdout'tadır; `colcon build --event-handlers console_direct+` ile görülür.
- `source`'lanmayan `bash -lc` ROS komutlarını görmez (.bashrc etkileşimsiz kabukta çalışmaz); `bash -ic` kullanın. Duman testi kendi source'unu yapar.
- `sitl.sh`/`gazebo.sh` `docker exec -it` kullanır: TTY olmadan çalışmaz (otomasyonda `script -qfc` ile sarın).
- Compose GPU anahtarı `deploy.resources.reservations.devices`; bu makinede (CDI) ve klasik runtime'da çalışır. Doğrulama: `docker exec rover_sim nvidia-smi -L`.

## Test durumu

Test edildi (Ubuntu + RTX 4060, sıfırdan derleme 2 turda): imaj derlendi, duman testi GEÇTİ (kayma 0.000 m, 4.86 m ileri, roll 0°), GUI'li Gazebo NVIDIA'da çalıştı, MAVProxy heartbeat alındı, kurulum.sh ön kontrolleri doğru çalıştı. Test EDİLMEDİ: GUI ekran görüntüsü, nogpu yolunun fiilen çalıştırılması, başka makinede kurulum.

## Yapılmaması gerekenler

- Dockerfile'a `|| true` eklemeyin; hataları gizlemeyin.
- Commit sabitlerini sebepsiz değiştirmeyin; derleme tekrarlanabilirliği bunlara bağlı.
- `ardupilot` için ayrı `~/ardupilot` klonu, MatekF405 derlemesi, lidar/SLAM ekleme (kapsam dışı).
- Ana ortam dışında `docker system prune`, imaj silme gibi yıkıcı komutlar çalıştırmayın (disk yetersizse kullanıcıya sorun).
- `git push` / yayın işlemlerini kullanıcı isteği olmadan yapmayın.
- Simülasyondaki `ARMING_SKIPCHK -1` ayarını gerçek araçta kullanmayın.
