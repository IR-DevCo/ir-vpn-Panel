#!/bin/bash
set -e
clear

# ========================================
# IR-VPN Installer
# Version: 1.0
# Fully automated installation
# ========================================

# ---------- Animated Banner (Iran Flag) ----------
GREEN='\033[42m'   # Green background
WHITE='\033[47m'   # White background
RED='\033[41m'     # Red background
NC='\033[0m'       # No color / reset

WIDTH=50  # Flag width

echo -e "\n"
for i in {1..3}; do
    printf "${GREEN}%${WIDTH}s${NC}\n" " "
done
for i in {1..3}; do
    printf "${WHITE}%${WIDTH}s${NC}\n" " "
done
for i in {1..3}; do
    printf "${RED}%${WIDTH}s${NC}\n" " "
done
echo -e "\n"
echo -e "\e[1;32m            IR-VPN Installer - Built by IR-Devco\e[0m"
sleep 2

# ---------- Root Check ----------
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with root privileges!"
  exit 1
fi

# ---------- OS Check ----------
if ! grep -qEi "ubuntu|debian" /etc/os-release; then
  echo "This installer supports Ubuntu/Debian only."
  exit 1
fi

# ---------- User Inputs ----------
read -p "Enter your server domain or IP: " DOMAIN
read -p "Email for SSL (Let's Encrypt): " EMAIL
read -p "Backend Port (default 8000): " BACKEND_PORT
BACKEND_PORT=${BACKEND_PORT:-8000}

# ---------- Port Check ----------
if ss -tulpn | grep -q ":$BACKEND_PORT"; then
    echo "Port $BACKEND_PORT is already in use. Please choose another port."
    exit 1
fi

# ---------- Install Dependencies ----------
echo "Installing dependencies..."
apt update
apt install -y python3 python3-pip nodejs npm git curl docker.io docker-compose ufw certbot nginx unzip

# ---------- Create Project Directory ----------
mkdir -p /opt/ir-vpn
# Assuming backend/frontend/config/bot/monitoring are next to install.sh
cp -r ../backend /opt/ir-vpn/backend
cp -r ../frontend /opt/ir-vpn/frontend
cp -r ../config /opt/ir-vpn/config
cp -r ../bot /opt/ir-vpn/bot
cp -r ../monitoring /opt/ir-vpn/monitoring

# ---------- Install Backend ----------
echo "Installing Backend..."
cd /opt/ir-vpn/backend
pip3 install --no-cache-dir -r requirements.txt

# Create systemd service for Backend
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

# ---------- Install Frontend ----------
echo "Installing Frontend..."
cd /opt/ir-vpn/frontend
npm install
npm run build

# Create systemd service for Frontend
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

# ---------- Install Xray/V2Ray ----------
echo "Installing Xray/V2Ray..."
mkdir -p /usr/local/bin
curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /tmp/xray.zip
unzip /tmp/xray.zip -d /usr/local/bin
chmod +x /usr/local/bin/xray

# Create systemd service for Xray
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

# ---------- Automatic SSL ----------
echo "Issuing SSL with Let's Encrypt..."
certbot --nginx -d $DOMAIN -m $EMAIL --agree-tos --non-interactive
systemctl reload nginx

# ---------- Setup Monitoring ----------
echo "Setting up monitoring..."
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

# ---------- Setup Telegram Bot ----------
echo "Setting up Telegram Bot..."
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

# ---------- Installation Completed ----------
clear
echo -e "\e[1;32m
========================================
IR-VPN installation completed!
Backend: http://$DOMAIN:$BACKEND_PORT
Frontend: http://$DOMAIN
Xray/V2Ray: Active
Telegram Bot: Active
SSL: Enabled with Let's Encrypt
========================================
\e[0m"
