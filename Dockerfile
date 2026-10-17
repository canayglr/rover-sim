# Rover simülasyonu: ArduPilot Rover SITL + Gazebo Harmonic + ROS 2 Humble.
# Tüm kaynak depolar belirli commit'lere SABİTLENMİŞTİR (tekrarlanabilir derleme).
# Hata gizlenmez: herhangi bir adım başarısız olursa derleme DURUR.
FROM osrf/ros:humble-desktop

SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# --- Temel paketler ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        nano vim git curl wget lsb-release gnupg sudo ca-certificates \
        default-jre python3-pip libdebuginfod1 \
    && rm -rf /var/lib/apt/lists/*

# --- Root olmayan kullanıcı (ros, uid 1000) ---
ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# --- Gazebo Harmonic ---
RUN curl -fsSL https://packages.osrfoundation.org/gazebo.gpg -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
       > /etc/apt/sources.list.d/gazebo-stable.list \
    && apt-get update && apt-get install -y gz-harmonic \
    && rm -rf /var/lib/apt/lists/*

# --- MAVProxy + pymavlink + ArduPilot waf derlemesi için Python ön koşulları ---
# (rosdep bunları getirmez; yokken ardupilot_sitl 'you need to install pexpect' ile düşer.
#  empy==3.3.4 ROS 2 Humble ile uyumlu sürümdür. install-prereqs-ubuntu.sh bilerek kullanılmıyor.)
RUN pip3 install --no-cache-dir MAVProxy pymavlink pexpect ptyprocess future lxml dronecan empy==3.3.4

USER $USERNAME
WORKDIR /home/$USERNAME
ENV GZ_VERSION=harmonic

# --- Sığ klon yardımcısı: yalnızca sabit commit'i çeker (tam geçmiş YOK) ---
RUN printf '%s\n' \
      'shallow() { # url sha dizin' \
      '  git init -q "$3" && cd "$3" && git remote add origin "$1" \' \
      '  && git fetch -q --depth 1 origin "$2" && git checkout -q FETCH_HEAD && cd - >/dev/null; }' \
      > ~/shallow.sh

# --- Micro-XRCE-DDS-Gen (sabit commit; yalnızca jar + scripts çalışma zamanında gerekir) ---
RUN source ~/shallow.sh \
    && shallow https://github.com/ardupilot/Micro-XRCE-DDS-Gen.git 4bc7ec2c7f77ae89cd216432f05470ad99f7faa1 ~/Micro-XRCE-DDS-Gen \
    && cd ~/Micro-XRCE-DDS-Gen \
    && git submodule update --init --recursive --depth 1 \
    && ./gradlew assemble \
    && ls share/microxrceddsgen/java/microxrceddsgen.jar \
    && find . -name .git -prune -exec rm -rf {} + \
    && rm -rf .gradle build ~/.gradle ~/.cache
ENV PATH="/home/ros/Micro-XRCE-DDS-Gen/scripts:${PATH}"

# --- PWM=0 yaması (PWM=0 iken nötr; yoksa rover açılışta geri kayar) ---
COPY --chown=ros:ros rover_sim/patches/ArduPilotPlugin_pwm0.patch /tmp/ArduPilotPlugin_pwm0.patch

# --- ROS 2 çalışma alanı: sığ klon + bağımlılıklar + derleme TEK katmanda ---
# colcon install/ dizini kopyalar (symlink YOK); ardurover ikilisi install/ardupilot_sitl/bin'de.
# Bu yüzden derleme sonrası src/, build/, log/ ve .git silinir (çalışma zamanında gerekmez).
# Derleme/yama başarısız olursa katman DURUR.
ENV MAKEFLAGS="-j4"
RUN source ~/shallow.sh && source /opt/ros/humble/setup.bash \
    && mkdir -p ~/ros2_ws/src && cd ~/ros2_ws/src \
    && shallow https://github.com/ArduPilot/ardupilot.git ccdfd945aefb19503f1d5687800c691e096b9d26 ardupilot \
    && (cd ardupilot && git submodule update --init --recursive --depth 1) \
    && shallow https://github.com/Jagadeesh-pradhani/ardupilot_gazebo 7276c750cdb7393c620880d996ce73ca4d916c11 ardupilot_gazebo \
    && shallow https://github.com/Jagadeesh-pradhani/ardupilot_gz 9f6742b9467eafd6747ced71d6e766205489cf1e ardupilot_gz \
    && shallow https://github.com/ArduPilot/SITL_Models.git d5d6017367a509b77886379c91207edc66f77652 ardupilot_sitl_models \
    && shallow https://github.com/micro-ROS/micro-ROS-Agent.git c93ee764e0d2ef4907aeb29233c68cb5f4b56976 micro_ros_agent \
    && shallow https://github.com/gazebosim/ros_gz.git 28e586a3d41f80f4a91e81902b8618c9d506022c ros_gz \
    && shallow https://github.com/ros/sdformat_urdf.git 7b73ddb8af07b8dd5cee5fa8231e982f4ad8c217 sdformat_urdf \
    && cd ardupilot_gazebo \
    && git apply --check /tmp/ArduPilotPlugin_pwm0.patch \
    && git apply /tmp/ArduPilotPlugin_pwm0.patch \
    && grep -q "PWM=0" src/ArduPilotPlugin.cc \
    && cd ~/ros2_ws \
    && sudo apt-get update && rosdep update \
    && rosdep install --from-paths src --ignore-src -r -y --skip-keys gazebo-ros-pkgs \
    && colcon build --packages-up-to ardupilot_gz_bringup ardupilot_sitl \
         --parallel-workers 2 --cmake-args -DCMAKE_BUILD_TYPE=Release \
    && test -x install/ardupilot_sitl/bin/ardurover \
    && rm -rf build log src ~/.ros/rosdep ~/.cache ~/shallow.sh /tmp/*.patch \
    && sudo rm -rf /var/lib/apt/lists/* \
    && mkdir -p ~/ros2_ws/src

# --- Ortam ---
RUN { \
      echo 'source /opt/ros/humble/setup.bash'; \
      echo 'source ~/ros2_ws/install/setup.bash'; \
      echo 'export GZ_VERSION=harmonic'; \
      echo 'export PATH=$PATH:~/Micro-XRCE-DDS-Gen/scripts'; \
    } >> ~/.bashrc

WORKDIR /home/ros
CMD ["bash"]
