# TransformerBlog

[中文版本](./README.md)

**A lightweight, JSON-driven static blog template built with Flutter Web &amp; Dart**

Easily deployable, fully configurable via JSON files, with built-in online content editing backend.

## Features

- **Flutter Web Frontend** — Smooth, responsive cross-platform blog UI
- **Dart Backend Service** — Lightweight API for online editing &amp; data parsing
- **JSON-Driven Configuration** — No code modification needed for daily content updates
- **Online Editing Support** — Edit articles, profile and friend links directly on the web
- **One-Click Server Deployment** — Full automatic deployment script (Nginx + systemd)
- **Dual Deployment Modes** — Static hosting / Full backend-enabled deployment

## Prerequisites

Make sure the following environments are installed on your local machine:

- Flutter SDK
- Dart SDK
- rsync &amp; openssh-client

Target server requirements:

- Nginx
- systemd (Most Linux servers)

## Quick Start (Local Development)

```bash
# Clone the repository
git clone [https://github.com/alittleshark-dev/TransformerBlog.git](https://github.com/alittleshark-dev/TransformerBlog.git)
cd TransformerBlog

# Install dependencies
flutter pub get

# Run locally in Chrome
flutter run -d chrome

# Build production web assets
flutter build web
```

## Project File Structure

All blog content and configurations are placed in `assets/data`, you can update your blog by editing these JSON files:

- `profile.json` — Personal homepage profile &amp; basic settings
- `friendship.json` — Friends / partner links configuration
- `articles.json` — All blog articles data

## Deployment

### 1. Static Deployment (GitHub Pages / Static CDN)

The `build/web` folder can be directly deployed to any static hosting service.

**Limitation**: Static deployment only provides frontend display. **Online editing function is unavailable** because no backend API service is running.

### 2. Full Server Deployment (With Backend &amp; Edit Function)

This script will automatically complete backend compilation, frontend packaging, systemd service registration and Nginx reverse proxy configuration.

Modify the configuration variables at the beginning before running.

```bash
# ================= Custom Configuration =================
SERVER_IP="xxx.xxx.xx.x"
DOMAIN="transformer-blog.ink"
REMOTE_DIR="/opt/transformer-blog"
NGINX_CONF_NAME="transformer-blog.conf"
SERVICE_NAME="transformer-blog"
# ========================================================

set -e
echo "[+] Starting full deployment..."

# ==========================================
# 1. Backend Deployment
# ==========================================
echo "[-] [Backend] Compiling Dart server..."
dart compile exe server/server.dart -o server/transformer_blog-server

echo "[-] [Backend] Preparing server directory..."
ssh root@$SERVER_IP "mkdir -p $REMOTE_DIR/server $REMOTE_DIR/assets/data"

echo "[-] [Backend] Uploading backend binary &amp; data files..."
scp server/transformer_blog-server root@$SERVER_IP:$REMOTE_DIR/server/
scp -r assets/data/* root@$SERVER_IP:$REMOTE_DIR/assets/data/ 2>/dev/null || true

echo "[-] [Backend] Configuring systemd service..."
ssh root@$SERVER< EOF
id transformer &>/dev/null || useradd -r -s /bin/false transformer
chown -R transformer:transformer $REMOTE_DIR

cat > /etc/systemd/system/$SERVICE_NAME< SERVICE_EOF
[Unit]
Description=Transformer Blog Backend Service
After=network.target

[Service]
Type=simple
User=transformer
WorkingDirectory=$REMOTE_DIR
ExecStart=$REMOTE_DIR/server/transformer_blog-server --data-dir assets/data --host 127.0.0.1 --port 8090
Restart=on-failure
RestartSec=2
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable --now $SERVICE_NAME
systemctl status $SERVICE_NAME --no-pager
EOF

# ==========================================
# 2. Frontend Deployment
# ==========================================
echo "[-] [Frontend] Building Flutter Web production assets..."
flutter build web

echo "[-] [Frontend] Syncing static files to server..."
rsync -av --delete build/web/ root@$SERVER_IP:$REMOTE_DIR/

# ==========================================
# 3. Nginx Reverse Proxy Configuration
# ==========================================
echo "[-] [Nginx] Generating &amp; loading config..."
ssh root@$SERVER< EOF
cat > /etc/nginx/conf.d/$NGINX< NGINX_EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $REMOTE_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass [http://127.0.0.1:8090/api/](http://127.0.0.1:8090/api/);
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
NGINX_EOF

nginx -t &amp;&amp; systemctl reload nginx
echo "[+] Nginx config applied successfully"
EOF

# ==========================================
# 4. Deployment Verification
# ==========================================
echo "[-] Verifying frontend &amp; API service..."
ssh root@$SERVER_IP "md5sum $REMOTE_DIR/main.dart.js"

curl -s -o /dev/null -w "API HTTP Status: %{http_code}\n" \
     --resolve "$DOMAIN:80:$(echo $SERVER_IP | tr -d '\n')" \
     "http://$DOMAIN/api/data/articles.json"

echo "[+] Deployment finished! Visit: http://$DOMAIN"
```

## Notes

- The backend runs on `127.0.0.1:8090` locally and is proxied by Nginx
- All content changes take effect instantly by updating JSON files
- Independent system user is used to ensure service security
- The service supports automatic restart on crash

## License (GPL v3.0)

This project is open-sourced under the **GNU General Public License v3.0**.

You are free to use, modify, and distribute this project, provided that you comply with the following terms:

- **Open Source Inheritance**: Any modified or derivative projects based on this repository must be open-sourced under the GPLv3.0 license.
- **Source Code Disclosure**: Full modified source code must be made public for commercial use or secondary distribution.
- **Copyright Reservation**: All original copyright and license statements in the project cannot be removed or modified.
- **No Proprietary Resale**: You are not allowed to sell, repackage, or distribute this project as closed-source commercial software.

For the full license terms, please refer to the `LICENSE` file in the project root directory.
