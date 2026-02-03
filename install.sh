#!/bin/bash
set -e
clear

# ========================================
# IR-VPN Installer
# نسخه: 1.0
# تمام مراحل نصب خودکار
# ========================================

# ---------- بنر متحرک ----------
echo -e "\e[1;32m
██████╗ ██╗██████╗      ██████╗ ██╗   ██╗
██╔══██╗██║██╔══██╗    ██╔═══██╗██║   ██║
██████╔╝██║██████╔╝    ██║   ██║██║   ██║
██╔═══╝ ██║██╔═══╝     ██║   ██║██║   ██║
██║     ██║██║         ╚██████╔╝╚██████╔╝
╚═╝     ╚═╝╚═╝          ╚═════╝  ╚═════╝
IR - VPN Installer
\e[0m"
sleep 2

# ---------- بررسی Root ----------
if [ "$EUID" -ne 0 ]; then
  echo "لطفاً این اسکریپت را با دسترسی root اجرا کنید!"
  exit 1
fi

# ---------- بررسی OS ----------
if ! grep -qEi "ubuntu|debian" /etc/os-release; then
  echo "این نصب فقط روی Ubuntu/Debian پشتیبانی می‌شود."
  exit 1
fi

# ---------- سوالات کاربر ----------
read -p "دامنه یا آی‌پی سرور خود را وارد کنید: " DOMAIN
read -p "ایمیل برای SSL (Let's Encrypt): " EMAIL
read -p "پورت Backend (پیش‌فرض 8000): " BACKEND_PORT
BACKEND_PORT=${BACKEND_PORT:-8000}

# ---------- بررسی پورت ----------
if ss -tulpn | grep -q ":$BACKEND_PORT"; then
    echo "پورت $BACKEND_PORT در حال استفاده است. لطفاً پورت دیگری انتخاب کنید."
    exit 1
fi

# ---------- نصب وابستگی‌ها ----------
echo "نصب وابستگی‌ها..."
apt update
apt install -y python3 python3-pip nodejs npm git curl docker.io docker-compose ufw certbot nginx

# ---------- ایجاد دایرکتوری پروژه ----------
mkdir -p /opt/ir-vpn
# توجه: این مسیر فرض می‌کند کدهای backend/frontend/config/bot/monitoring کنار install.sh هستند
cp -r ../backend /opt/ir-vpn/backend
cp -r ../frontend /opt/ir-vpn/frontend
cp -r ../config /opt/ir-vpn/config
cp -r ../bot /opt/ir-vpn/bot
cp -r ../monitoring /opt/ir-vpn/monitoring

# ---------- نصب Backend ----------
echo "نصب Backend..."
cd /opt/ir-vpn/backend
pip3 install --no-cache-dir -r requirements.txt

# ایجاد systemd service برای Backend
cat >/etc/systemd/system/backend.service <<EOL
[Unit]
Description=IR-VPN Backend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ir-vpn/backend
ExecStart=/usr/local/bin/uvicorn app.main:app --host 0.0.0.0 --port $BACKEND_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable backend
systemctl start backend

# ---------- نصب Frontend ----------
echo "نصب Frontend..."
cd /opt/ir-vpn/frontend
npm install
npm run build

# ایجاد systemd service برای Frontend
cat >/etc/systemd/system/frontend.service <<EOL
[Unit]
Description=IR-VPN Frontend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ir-vpn/frontend
ExecStart=/usr/bin/npm run start
Restart=always

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable frontend
systemctl start frontend

# ---------- نصب Xray/V2Ray ----------
echo "نصب Xray/V2Ray..."
mkdir -p /usr/local/bin
curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /tmp/xray.zip
unzip /tmp/xray.zip -d /usr/local/bin
chmod +x /usr/local/bin/xray

# ایجاد systemd service برای Xray
cat >/etc/systemd/system/xray.service <<EOL
[Unit]
Description=IR-VPN Xray Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xray -config /opt/ir-vpn/config/xray_config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable xray
systemctl start xray

# ---------- نصب SSL خودکار ----------
echo "صدور SSL با Let's Encrypt..."
certbot --nginx -d $DOMAIN -m $EMAIL --agree-tos --non-interactive
systemctl reload nginx

# ---------- نصب Monitoring ----------
echo "راه‌اندازی مانیتورینگ..."
mkdir -p /opt/ir-vpn/monitoring/logs
cat >/etc/systemd/system/server_monitor.service <<EOL
[Unit]
Description=IR-VPN Server Monitoring
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /opt/ir-vpn/monitoring/server_monitor.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable server_monitor
systemctl start server_monitor

# ---------- نصب Bot تلگرام ----------
echo "راه‌اندازی Bot تلگرام..."
cat >/etc/systemd/system/admin_bot.service <<EOL
[Unit]
Description=IR-VPN Admin Telegram Bot
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /opt/ir-vpn/bot/admin_bot.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable admin_bot
systemctl start admin_bot

# ---------- Firewall ----------
ufw allow 22
ufw allow 80
ufw allow 443
ufw allow $BACKEND_PORT
ufw --force enable

# ---------- نصب کامل شد ----------
clear
echo -e "\e[1;32m
========================================
IR-VPN نصب شد!
Backend: http://$DOMAIN:$BACKEND_PORT
Frontend: http://$DOMAIN
Xray/V2Ray: فعال
Bot تلگرام: فعال
SSL: فعال با Let's Encrypt
========================================
\e[0m"
