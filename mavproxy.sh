#!/bin/bash
# Terminal 3: MAVProxy konsolu. SITL başlatılırken MAVProxy zaten çalışır ve UDP 14550'ye
# (kullanıcı konsolu/GCS) ile 14551'e (betikler) çıkış verir. Bu betik 14550'yi dinleyen
# ikinci bir MAVProxy açar; 14551 test/betikler için boş bırakılır.
exec docker exec -it rover_sim bash -ic 'mavproxy.py --master=udpin:127.0.0.1:14550 --console --map "$@"' _ "$@"
