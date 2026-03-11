#!/bin/bash
# templates/nginx/build.sh
# Runs inside systemd-nspawn chroot during GitHub Actions build
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# === Install packages ===
apt-get update
apt-get install -y --no-install-recommends \
	nginx \
	curl \
	ca-certificates

# === Create shared group for volumes (if configured) ===
if [[ -n "${TEMPLATE_GID:-}" ]]; then
	groupadd -g "$TEMPLATE_GID" shared
	usermod -aG shared www-data
fi

# === Configure nginx ===
cat >/etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

# === Welcome page ===
cat >/var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LXC Template - Nginx</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { color: #333; margin-bottom: 20px; }
        code {
            background: #e8e8e8;
            padding: 2px 8px;
            border-radius: 4px;
            font-family: monospace;
        }
        .info { color: #666; margin-top: 30px; }
        a { color: #0066cc; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Nginx is running!</h1>
        <p>This container was created from an LXC template.</p>
        <p>Template version: <code>__VERSION__</code></p>
        <div class="info">
            <p>Useful commands:</p>
            <ul>
                <li><code>template-update status</code> - Check for updates</li>
                <li><code>template-update update</code> - Apply updates</li>
                <li><code>systemctl status nginx</code> - Check nginx status</li>
            </ul>
            <p>
                <a href="https://github.com/Deroy2112/proxmox-lxc-templates">Template Repository</a>
            </p>
        </div>
    </div>
</body>
</html>
EOF

# Insert version into HTML
sed -i "s/__VERSION__/${TEMPLATE_VERSION}/" /var/www/html/index.html

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
systemctl enable nginx

# === Cleanup ===
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
