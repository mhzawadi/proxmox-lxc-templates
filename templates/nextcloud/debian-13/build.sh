#!/bin/bash
# templates/jellyfin/build.sh
# Runs inside systemd-nspawn chroot during GitHub Actions build
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# === Install dependencies ===
apt-get update
apt-get install -y --no-install-recommends \
	curl gnupg2 ca-certificates lsb-release debian-archive-keyring

# === Create nextcloud user/group with fixed IDs (for shared volumes) ===
if [[ -n "${TEMPLATE_GID:-}" ]]; then
  groupadd -g "$TEMPLATE_GID" nextcloud
fi
if [[ -n "${TEMPLATE_UID:-}" ]]; then
	useradd -r -u "$TEMPLATE_UID" -g "${TEMPLATE_GID:-nextcloud}" \
		-s /usr/sbin/nologin -d /var/lib/nextcloud nextcloud
fi

# === Add nginx and PHP repository ===
mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.sury.org/nginx/apt.gpg |
	gpg --dearmor -o /etc/apt/keyrings/php.gpg
chmod 644 /etc/apt/keyrings/php.gpg

curl -fsSL https://nginx.org/keys/nginx_signing.key \
-o /etc/apt/keyrings/nginx.asc
chmod 644 /etc/apt/keyrings/nginx.asc

cat >/etc/apt/sources.list.d/nginx.sources <<'EOF'
Components: nginx
Enabled: yes
X-Repolib-Name: nginx
Signed-By: /etc/apt/keyrings/nginx.asc
Suites: trixie
Types: deb
URIs: http://nginx.org/packages/debian
EOF

cat >/etc/apt/sources.list.d/php.sources <<'EOF'
Components: main
Enabled: yes
X-Repolib-Name: php
Signed-By: /etc/apt/keyrings/php.gpg
Suites: trixie
Types: deb
URIs: https://packages.sury.org/php/
EOF

# === Install nginx and PHP ===
apt-get update
apt-get install -y --no-install-recommends \
  nginx \
  php8.3-apcu \
  php8.3-bcmath \
  php8.3-bz2 \
  php8.3-cli \
  php8.3-common \
  php8.3-curl \
  php8.3-dev \
  php8.3-fpm \
  php8.3-gd \
  php8.3-gmp \
  php8.3-igbinary \
  php8.3-imap \
  php8.3-intl \
  php8.3-mbstring \
  php8.3-mbstring-dbgsym \
  php8.3-memcached \
  php8.3-msgpack \
  php8.3-mysql \
  php8.3-opcache \
  php8.3-readline \
  php8.3-redis \
  php8.3-sqlite3 \
  php8.3-xml \
  php8.3-xmlrpc \
  php8.3-zip \
  php8.3-imagick \
  php-pear \
  pkg-php-tools \
  libmagickwand-dev \
  ffmpeg \
  mariadb-client

# === Install pecl libarys ===
# pecl install mcrypt imagick

# === Copy PHP config into place ===
mv "/tmp/files/opcache.ini" /etc/php/8.3/mods-available/opcache.ini
mv "/tmp/files/php-fpm.conf" /etc/php/8.3/fpm/php-fpm.conf
mv "/tmp/files/pool.conf" /etc/php/8.3/fpm/pool.d/www.conf
mv "/tmp/files/php.ini" /etc/php/8.3/fpm/php.ini

# === Copy nginz config into place ===
mkdir /etc/nginx/sites-available
mkdir /etc/nginx/sites-enabled
mv "/tmp/files/nginx.conf" /etc/nginx/nginx.conf
mv "/tmp/files/nginx_nextcloud.conf" /etc/nginx/sites-available/default.conf
mv "/tmp/files/upstream.conf" /etc/nginx/conf.d/upstream.conf
ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

# == Download and unpack nextcloud ===
mkdir /var/www/
mkdir /var/lib/nextcloud
wget https://download.nextcloud.com/server/releases/nextcloud-32.0.6.zip
unzip nextcloud-v32.0.6.zip
mv nextcloud /var/www/html
chown nextcloud:nextcloud /var/www/html -R

# === Make sure nginx and PHP auto start ===
/usr/bin/systemctl enable nginx php8.3-fpm

# === Template info ===
cat >/etc/template-info <<EOF
TEMPLATE_NAME="${TEMPLATE_NAME}"
TEMPLATE_REPO="${TEMPLATE_REPO}"
TEMPLATE_VERSION="${TEMPLATE_VERSION}"
INSTALL_DATE="__DATE__"
EOF

# === Install template-update tool ===
repo_raw_url=$(echo "${TEMPLATE_REPO}" | sed 's|github.com|raw.githubusercontent.com|')/main
curl -fsSL "${repo_raw_url}/scripts/template-update.sh" \
	-o /usr/local/bin/template-update
chmod +x /usr/local/bin/template-update

# === Enable services ===
systemctl enable jellyfin

# === Cleanup ===
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
