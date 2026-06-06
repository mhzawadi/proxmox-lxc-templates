#!/bin/bash
# templates/pulsar/build.sh
# Runs inside systemd-nspawn chroot during GitHub Actions build
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export DISPLAY=:1
export VNC_PORT=5901
export NO_VNC_PORT=8080
export VNC_COL_DEPTH=32
export VNC_RESOLUTION=1280x900
export DEBIAN_FRONTEND=noninteractive
export TERM=xterm

readonly PULSAR_VER="${TEMPLATE_VERSION%-*}"

# === Install dependencies ===
apt-get update && \
apt-get install --no-install-recommends -y \
  xvfb xauth fluxbox git \
  wget sudo git bzip2 python3 ca-certificates \
  tigervnc-standalone-server tigervnc-common firefox-esr; \
apt-get clean; \
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
mkdir /src; \
git clone --branch v1.7.0 --single-branch https://github.com/novnc/noVNC.git /opt/noVNC; \
git clone --branch v0.13.0 --single-branch https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify; \
ln -s /opt/noVNC/vnc_lite.html /opt/noVNC/index.html

# === Create shared group and pulsar user ===
if [[ -n "${TEMPLATE_GID:-}" ]]; then
	groupadd -g "$TEMPLATE_GID" shared
fi

if [[ -n "${TEMPLATE_UID:-}" ]]; then
  useradd -r -u "$TEMPLATE_UID" -g shared -m pulsar
else
	useradd -r -g shared -d /var/lib/pulsar -s /usr/sbin/nologin pulsar
fi

# === Download and extract pulsar ===
APT_FILE=Linux.pulsar_${PULSAR_VER}_amd64.deb;

wget https://github.com/pulsar-edit/pulsar/releases/download/v${PULSAR_VER}/${APT_FILE};
apt-get update;
apt-get -y install ./${APT_FILE}
apt-get clean;
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*;
rm -f ./${APT_FILE}

# === Create systemd service ===
cat > /home/pulsar/.profile << 'EOF'
if [[ -z "$DISPLAY" ]] && [[ $(tty) = /dev/tty1 ]]; then
  echo "Run a thing"
  pulsar
fi
EOF

cat > /var/spool/cron/crontabs/pulsar << 'EOF'
@reboot /opt/noVNC/utils/novnc_proxy --vnc localhost:5901 --listen 8080
EOF

cat > /etc/systemd/system/vncserver.service << 'EOF'
[Unit]
Description=Start TigerVNC server at startup
After=network.target

[Service]
Type=forking
User=USERNAME
PAMName=login
PIDFile=/home/pulsar/.vnc/%H:1.pid
ExecStart=/usr/bin/tigervncserver -depth 32 -geometry 1280x900 -SecurityTypes None -localhost no --I-KNOW-THIS-IS-INSECURE
ExecStop=/usr/bin/tigervncserver -kill :1
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# === Template info ===
cat > /etc/template-info << EOF
TEMPLATE_NAME="${TEMPLATE_NAME}"
TEMPLATE_REPO="${TEMPLATE_REPO}"
TEMPLATE_VERSION="${TEMPLATE_VERSION}"
INSTALL_DATE="__DATE__"
EOF

# === Install template-update tool ===
repo_raw_url="${TEMPLATE_REPO/github.com/raw.githubusercontent.com}/main"
curl -fsSL "${repo_raw_url}/scripts/template-update.sh" \
	-o /usr/local/bin/template-update
chmod +x /usr/local/bin/template-update

# === Enable services ===
systemctl enable vncserver

# === Cleanup ===
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
