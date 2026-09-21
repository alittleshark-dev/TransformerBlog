# TransformerBlog

[English Version](./README_EN.md)

**基于 Flutter Web + Dart 构建的轻量级、可在线编辑的静态博客模板**

全程 JSON 配置驱动，无需改代码，支持静态托管与完整服务部署，开箱即用、自动化部署上线。

## 项目特性

- **Flutter Web 前端** — 界面流畅、自适应多端，现代化博客UI
- **Dart 轻量后端** — 提供完整API能力，支持网页在线编辑内容
- **零代码配置** — 所有博客内容、信息、友链均通过JSON文件配置
- **在线编辑功能** — 网页端直接修改文章、个人资料、友情链接
- **一键服务器部署** — 自动编译后端、打包前端、配置Nginx与开机自启
- **双部署模式** — 支持GitHub Pages静态部署 / 服务器全功能部署

## 环境依赖

本地开发环境需提前安装：

- Flutter SDK
- Dart SDK
- rsync、openssh-client

服务器运行环境：

- Nginx
- systemd（主流Linux系统默认自带）

## 快速开始

```bash
# 克隆项目仓库
git clone [https://github.com/alittleshark-dev/TransformerBlog.git](https://github.com/alittleshark-dev/TransformerBlog.git)
cd TransformerBlog

# 安装项目依赖
flutter pub get

# Chrome 本地调试运行
flutter run -d chrome

# 打包生产 Web 静态资源
flutter build web
```

## 项目配置

博客所有内容均存放于 `assets/data` 目录，修改对应JSON文件即可更新博客内容，无需编译代码：

- `profile.json` — 个人主页资料、博客基础配置
- `friendship.json` — 友情链接、友链列表配置
- `articles.json` — 博客所有文章内容、标题、排序配置

## 如何部署

### 1. 静态部署（GitHub Pages / 静态CDN）

打包生成的 `build/web` 目录，可直接托管至任意静态网站服务。

**⚠**：纯静态部署仅展示博客页面，**无法使用在线编辑功能**（该功能依赖后端API服务）。

### 2. 服务器全功能部署（支持在线编辑）

一键自动化脚本，自动完成后端编译、前端打包、文件上传、Nginx反向代理、系统服务配置、故障自启，部署即上线。

**使用前请修改脚本顶部自定义配置项**，替换为自己的服务器IP与域名。

```bash
# ================= 自定义配置（请手动修改） =================
SERVER_IP="你的服务器IP"
DOMAIN="你的域名"
REMOTE_DIR="/opt/transformer-blog"
NGINX_CONF_NAME="transformer-blog.conf"
SERVICE_NAME="transformer-blog"
# ==========================================================

set -e
echo "[+] 开始全自动部署..."

# ==========================================
# 1. 部署 Dart 后端服务
# ==========================================
echo "[-] [后端] 编译Dart服务端二进制文件..."
dart compile exe server/server.dart -o server/transformer_blog-server

echo "[-] [后端] 创建服务器目录..."
ssh root@$SERVER_IP "mkdir -p $REMOTE_DIR/server $REMOTE_DIR/assets/data"

echo "[-] [后端] 上传服务端程序与配置数据..."
scp server/transformer_blog-server root@$SERVER_IP:$REMOTE_DIR/server/
scp -r assets/data/* root@$SERVER_IP:$REMOTE_DIR/assets/data/ 2>/dev/null || true

echo "[-] [后端] 配置系统守护进程..."
ssh root@$SERVER_IP << EOF
id transformer &>/dev/null || useradd -r -s /bin/false transformer
chown -R transformer:transformer $REMOTE_DIR

cat > /etc/systemd/system/$SERVICE_NAME.service << SERVICE_EOF
[Unit]
Description=TransformerBlog 博客后端服务
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
# 2. 部署 Flutter Web 前端
# ==========================================
echo "[-] [前端] 打包生产环境静态资源..."
flutter build web

echo "[-] [前端] 同步静态文件至服务器..."
rsync -av --delete build/web/ root@$SERVER_IP:$REMOTE_DIR/

# ==========================================
# 3. 配置 Nginx 反向代理
# ==========================================
echo "[-] [Nginx] 生成并加载反向代理配置..."
ssh root@$SERVER_IP << EOF
cat > /etc/nginx/conf.d/$NGINX_CONF_NAME << NGINX_EOF
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

nginx -t && systemctl reload nginx
echo "[+] Nginx 配置生效成功"
EOF

# ==========================================
# 4. 部署结果校验
# ==========================================
echo "[-] 校验前端文件与后端API服务状态..."
ssh root@$SERVER_IP "md5sum $REMOTE_DIR/main.dart.js"

curl -s -o /dev/null -w "API 接口状态码: %{http_code}\n" \
     --resolve "$DOMAIN:80:$(echo $SERVER_IP | tr -d '\n')" \
     "http://$DOMAIN/api/data/articles.json"

echo "[+] 部署完成！博客地址: http://$DOMAIN"
```

## 项目说明

- 后端服务监听本地 `127.0.0.1:8090`，通过 Nginx 反向代理对外提供接口
- 修改JSON配置文件后即时生效，无需重新打包部署
- 创建独立系统用户运行服务，权限隔离，提升服务器安全性
- 服务支持异常自动重启，保障博客长期稳定运行

## 开源协议（GPL v3.0）

本项目基于 **GNU General Public License v3.0** 开源。

你可以自由使用、修改、分发本项目代码，但必须遵循以下规则：

- **开源继承**：基于本项目修改、二次开发后的项目，必须同样使用 GPLv3.0 协议开源
- **公开源码**：商用或二次分发时，必须公开修改后的完整源码
- **保留版权**：项目所有版权声明、开源协议标识不可删除
- **禁止闭源倒卖**：禁止将本项目修改后作为闭源付费项目售卖

完整开源协议详情请查看项目根目录 `LICENSE` 文件。
