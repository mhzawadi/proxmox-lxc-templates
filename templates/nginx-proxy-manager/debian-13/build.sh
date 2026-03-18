#!/bin/bash
# templates/nginx-proxy-manager/build.sh
# Runs inside systemd-nspawn chroot during GitHub Actions build
# Based on community-scripts/ProxmoxVE bare-metal installation
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

readonly NPM_VERSION="2.13.5"
readonly NPM_DIR="/opt/nginxproxymanager"
readonly APP_DIR="/app"
readonly DATA_DIR="/data"

# === Install base dependencies ===
apt-get update
apt-get install -y --no-install-recommends \
	curl \
	ca-certificates \
	gnupg \
	git \
	build-essential \
	python3 \
	python3-dev \
	python3-pip \
	python3-venv \
	python3-cffi \
	openssl \
	apache2-utils \
	logrotate

# === Setup Certbot in virtualenv ===
python3 -m venv /opt/certbot
/opt/certbot/bin/pip install --upgrade pip setuptools wheel
/opt/certbot/bin/pip install certbot certbot-dns-cloudflare
ln -sf /opt/certbot/bin/certbot /usr/local/bin/certbot

# === Add Node.js repository (Node.js 22 LTS) ===
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key |
	gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
chmod 644 /etc/apt/keyrings/nodesource.gpg

cat >/etc/apt/sources.list.d/nodesource.sources <<'EOF'
Types: deb
URIs: https://deb.nodesource.com/node_22.x
Suites: nodistro
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/nodesource.gpg
EOF

# === Add OpenResty repository (using bookworm - compatible with trixie) ===
curl -fsSL https://openresty.org/package/pubkey.gpg |
	gpg --dearmor -o /etc/apt/keyrings/openresty.gpg
chmod 644 /etc/apt/keyrings/openresty.gpg

cat >/etc/apt/sources.list.d/openresty.sources <<'EOF'
Types: deb
URIs: https://openresty.org/package/debian
Suites: bookworm
Components: openresty
Architectures: amd64
Signed-By: /etc/apt/keyrings/openresty.gpg
EOF

# === Install Node.js and OpenResty ===
apt-get update
apt-get install -y --no-install-recommends \
	nodejs \
	openresty

# === Download NPM source ===
mkdir -p "$NPM_DIR"
curl -fsSL "https://github.com/NginxProxyManager/nginx-proxy-manager/archive/refs/tags/v${NPM_VERSION}.tar.gz" \
	-o /tmp/npm.tar.gz
tar -xzf /tmp/npm.tar.gz -C "$NPM_DIR" --strip-components=1

# === Create symbolic links for binaries ===
ln -sf /usr/bin/python3 /usr/bin/python
ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/sbin/nginx
ln -sf /usr/local/openresty/nginx /etc/nginx

# === Update version in package.json ===
sed -i "s|\"version\": \"2.0.0\"|\"version\": \"${NPM_VERSION}\"|" "$NPM_DIR/backend/package.json"
sed -i "s|\"version\": \"2.0.0\"|\"version\": \"${NPM_VERSION}\"|" "$NPM_DIR/frontend/package.json"

# === Patch nginx config for non-Docker environment ===
# Disable daemon mode (systemd manages the process)
sed -i 's+^daemon+#daemon+g' "$NPM_DIR/docker/rootfs/etc/nginx/nginx.conf"

# Fix include paths to absolute
NGINX_CONFS=$(find "$NPM_DIR" -type f -name "*.conf")
for NGINX_CONF in $NGINX_CONFS; do
	sed -i 's+include conf.d+include /etc/nginx/conf.d+g' "$NGINX_CONF"
done

# === Create directory structure ===
mkdir -p /var/www/html /etc/nginx/logs
mkdir -p /tmp/nginx/body
mkdir -p /run/nginx
mkdir -p "$APP_DIR"/frontend/images
mkdir -p "$DATA_DIR"/{nginx,logs,letsencrypt,access,custom_ssl,letsencrypt-acme-challenge}
mkdir -p "$DATA_DIR/nginx"/{default_host,default_www,proxy_host,redirection_host,dead_host,stream,temp}
mkdir -p /var/lib/nginx/cache/{public,private}
mkdir -p /var/cache/nginx/proxy_temp

chmod -R 777 /var/cache/nginx
chown root /tmp/nginx

# === Copy files from docker rootfs ===
cp -r "$NPM_DIR/docker/rootfs/var/www/html/"* /var/www/html/
cp -r "$NPM_DIR/docker/rootfs/etc/nginx/"* /etc/nginx/
cp "$NPM_DIR/docker/rootfs/etc/letsencrypt.ini" /etc/letsencrypt.ini
cp "$NPM_DIR/docker/rootfs/etc/logrotate.d/nginx-proxy-manager" /etc/logrotate.d/nginx-proxy-manager

# === Create additional symlinks ===
ln -sf /etc/nginx/nginx.conf /etc/nginx/conf/nginx.conf

# === Remove dev config ===
rm -f /etc/nginx/conf.d/dev.conf

# === Copy backend ===
cp -r "$NPM_DIR/backend/"* "$APP_DIR/"

# === Build Frontend ===
cd "$NPM_DIR/frontend"

export NODE_OPTIONS="--max_old_space_size=2048"
npm install
npm run locale-compile
npm run build

cp -r "$NPM_DIR/frontend/dist/"* "$APP_DIR/frontend/"
cp -r "$NPM_DIR/frontend/public/images/"* "$APP_DIR/frontend/images/"

# === Initialize Backend ===
cd "$APP_DIR"
rm -rf "$APP_DIR/config/default.json"

mkdir -p "$APP_DIR/config"
cat >"$APP_DIR/config/production.json" <<'EOF'
{
  "database": {
    "engine": "knex-native",
    "knex": {
      "client": "sqlite3",
      "connection": {
        "filename": "/data/database.sqlite"
      }
    }
  }
}
EOF

npm install

# === Generate dummy SSL certificates ===
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
	-subj "/O=Nginx Proxy Manager/OU=Dummy Certificate/CN=localhost" \
	-keyout "$DATA_DIR/nginx/dummykey.pem" \
	-out "$DATA_DIR/nginx/dummycert.pem"

# === Patch nginx.conf for root user (no npm user in LXC) ===
sed -i 's/user npm/user root/g; s/^pid/#pid/g' /etc/nginx/nginx.conf
sed -r -i 's/^([[:space:]]*)su npm npm/\1#su npm npm/g;' /etc/logrotate.d/nginx-proxy-manager

# === Create shared group for volumes (if configured) ===
if [[ -n "${TEMPLATE_GID:-}" ]]; then
	groupadd -g "$TEMPLATE_GID" shared
	usermod -aG shared root
fi

# === Create resolver config generator (runs at first boot) ===
cat >/usr/local/bin/npm-resolvers-update <<'EOF'
#!/bin/bash
# Generate resolver config from current DNS settings
echo resolver "$(awk 'BEGIN{ORS=" "} $1=="nameserver" {print ($2 ~ ":")? "["$2"]": $2}' /etc/resolv.conf);" > /etc/nginx/conf.d/include/resolvers.conf
EOF
chmod +x /usr/local/bin/npm-resolvers-update

# === Create systemd service ===
cat >/lib/systemd/system/npm.service <<'EOF'
[Unit]
Description=Nginx Proxy Manager
After=network.target
Wants=openresty.service

[Service]
Type=simple
Environment=NODE_ENV=production
ExecStartPre=-/bin/mkdir -p /tmp/nginx/body /data/letsencrypt-acme-challenge
ExecStartPre=/usr/local/bin/npm-resolvers-update
ExecStart=/usr/bin/node index.js --abort_on_uncaught_exception --max_old_space_size=250
WorkingDirectory=/app
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# === Create logrotate config ===
cat >/etc/logrotate.d/npm <<'EOF'
/data/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        [ -f /run/nginx/nginx.pid ] && kill -USR1 $(cat /run/nginx/nginx.pid)
    endscript
}
EOF

# === Template info ===
cat >/etc/template-info <<EOF
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
systemctl enable openresty
systemctl enable npm

# === Cleanup ===
rm -rf /tmp/npm.tar.gz "$NPM_DIR"
npm cache clean --force
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# === Print info ===
cat <<'INFO'
=============================================
Nginx Proxy Manager installed successfully
=============================================
Admin UI:     http://<container-ip>:81
HTTP Port:    80
HTTPS Port:   443

Default credentials:
  Email:    admin@example.com
  Password: changeme
=============================================
INFO
