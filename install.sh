#!/bin/bash
set -e
clear

# ========================================
# IR-VPN Installer
# Version: 1.0
# Fully automated installation
# ========================================

# ---------- Colors ----------
GREEN_BG='\033[42m'
WHITE_BG='\033[47m'
RED_BG='\033[41m'
NC='\033[0m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'

WIDTH=50

# ---------- Animated Banner ----------
for i in {1..3}; do printf "${GREEN_BG}%${WIDTH}s${NC}\n" " "; done
for i in {1..3}; do printf "${WHITE_BG}%${WIDTH}s${NC}\n" " "; done
for i in {1..3}; do printf "${RED_BG}%${WIDTH}s${NC}\n" " "; done

echo -e "\n${WHITE}          ███████╗██████╗ ██╗   ██╗ - IR-VPN Installer${NC}"
echo -e "${WHITE}          Built by IR-Devco${NC}\n"
sleep 2

# ---------- Root Check ----------
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run this script with root privileges!${NC}"
  exit 1
fi

# ---------- OS Check ----------
if ! grep -qEi "ubuntu|debian" /etc/os-release; then
  echo -e "${RED}Error: This installer supports Ubuntu/Debian only.${NC}"
  exit 1
fi

# ---------- User Inputs ----------
while true; do
  read -p "Enter your server domain or IP: " DOMAIN
  if [[ $DOMAIN =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || [[ $DOMAIN =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    break
  else
    echo -e "${RED}Invalid domain or IP.${NC}"
  fi
done

while true; do
  read -p "Email for SSL (Let's Encrypt): " EMAIL
  if [[ $EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    break
  else
    echo -e "${RED}Invalid email format.${NC}"
  fi
done

while true; do
  read -p "Backend Port (default 8000): " BACKEND_PORT
  BACKEND_PORT=${BACKEND_PORT:-8000}
  if [[ $BACKEND_PORT =~ ^[0-9]+$ ]] && [ $BACKEND_PORT -ge 1 ] && [ $BACKEND_PORT -le 65535 ]; then
    break
  else
    echo -e "${RED}Invalid port.${NC}"
  fi
done

# ---------- Install Dependencies (NO DOCKER) ----------
echo -e "${BLUE}Installing dependencies...${NC}"
apt update
apt install -y \
  python3 python3-pip \
  nodejs npm \
  git curl ufw \
  nginx certbot python3-certbot-nginx \
  unzip

# ---------- Create Project Directory ----------
mkdir -p /opt/ir-vpn
cp -r ../backend /opt/ir-vpn/backend
cp -r ../frontend /opt/ir-vpn/frontend
cp -r ../config /opt/ir-vpn/config
cp -r ../bot /opt/ir-vpn/bot
cp -r ../monitoring /opt/ir-vpn/monitoring

# ---------- Backend ----------
echo -e "${BLUE}Installing Backend...${NC}"
cd /opt/ir-vpn/backend
pip3 install --upgrade pip
pip3 install -r requirements.txt

cat >/etc/systemd/system/backend.service <<EOF
[Unit]
Description=IR-VPN Backend
After=network.target

[Service]
User=root
WorkingDirectory=/opt/ir-vpn/backend
ExecStart=/usr/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port $BACKEND_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable backend
systemctl start backend

# ---------- Frontend ----------
echo -e "${BLUE}Installing Frontend...${NC}"
cd /opt/ir-vpn/frontend
npm install
npm run build

cat >/etc/systemd/system/frontend.service <<EOF
[Unit]
Description=IR-VPN Frontend
After=network.target

[Service]
User=root
WorkingDirectory=/opt/ir-vpn/frontend
ExecStart=/usr/bin/npm run start
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable frontend
systemctl start frontend

# ---------- Xray ----------
echo -e "${BLUE}Installing Xray...${NC}"
curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /tmp/xray.zip
unzip -o /tmp/xray.zip -d /usr/local/bin
chmod +x /usr/local/bin/xray

cat >/etc/systemd/system/xray.service <<EOF
[Unit]
Description=IR-VPN Xray
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/xray -config /opt/ir-vpn/config/xray_config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray
systemctl start xray

# ---------- SSL ----------
echo -e "${BLUE}Issuing SSL...${NC}"
certbot --nginx -d $DOMAIN -m $EMAIL --agree-tos --non-interactive

# ---------- Telegram Bot ----------
cat >/etc/systemd/system/admin_bot.service <<EOF
[Unit]
Description=IR-VPN Telegram Bot
After=network.target

[Service]
User=root
ExecStart=/usr/bin/python3 /opt/ir-vpn/bot/admin_bot.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable admin_bot
systemctl start admin_bot

# ---------- Firewall ----------
ufw allow OpenSSH
ufw allow 80
ufw allow 443
ufw allow $BACKEND_PORT
ufw --force enable

# ---------- Done ----------
clear
echo -e "\e[1;32m
========================================
IR-VPN installation completed!
Backend:  https://$DOMAIN:$BACKEND_PORT
Frontend: https://$DOMAIN
Xray:     Active
Bot:      Active
SSL:      Enabled
Built by IR-Devco
========================================
\e[0m"
