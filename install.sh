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

# ---------- Animated Banner (Iran Flag + IR-VPN) ----------
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

# ---------- User Inputs with Validation ----------
# Validate domain/IP
while true; do
    read -p "Enter your server domain or IP: " DOMAIN
    if [[ $DOMAIN =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || [[ $DOMAIN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${GREEN}Domain/IP accepted: $DOMAIN${NC}"
        break
    else
        echo -e "${RED}Invalid domain or IP format. Example: example.com or 123.123.123.123${NC}"
    fi
done

# Validate email
while true; do
    read -p "Email for SSL (Let's Encrypt): " EMAIL
    if [[ $EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo -e "${GREEN}Email accepted: $EMAIL${NC}"
        break
    else
        echo -e "${RED}Invalid email format. Example: user@example.com${NC}"
    fi
done

# Validate backend port
while true; do
    read -p "Backend Port (default 8000): " BACKEND_PORT
    BACKEND_PORT=${BACKEND_PORT:-8000}
    if [[ $BACKEND_PORT =~ ^[0-9]+$ ]] && [ $BACKEND_PORT -ge 1 ] && [ $BACKEND_PORT -le 65535 ]; then
        if ss -tulpn | grep -q ":$BACKEND_PORT"; then
            echo -e "${YELLOW}Warning: Port $BACKEND_PORT is already in use.${NC}"
        else
            echo -e "${GREEN}Port accepted: $BACKEND_PORT${NC}"
            break
        fi
    else
        echo -e "${RED}Invalid port number. Enter a number between 1 and 65535.${NC}"
    fi
done

# ---------- Install Dependencies ----------
echo -e "${BLUE}Installing dependencies...${NC}"
apt update
apt install -y python3 python3-pip nodejs npm git curl docker.io docker-compose ufw certbot nginx unzip

# ---------- Create Project Directory ----------
mkdir -p /opt/ir-vpn
cp -r ../backend /opt/ir-vpn/backend
cp -r ../frontend /opt/ir-vpn/frontend
cp -r ../config /opt/ir-vpn/config
cp -r ../bot /opt/ir-vpn/bot
cp -r ../monitoring /opt/ir-vpn/monitoring

# ---------- Install Backend ----------
echo -e "${BLUE}Installing Backend...${NC}"
cd /opt/ir-vpn/backend
pip3 install --no-cache-dir -r requirements.txt

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
echo -e "${BLUE}Installing Frontend...${NC}"
cd /opt/ir-vpn/frontend
npm install
npm run build

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
echo -e "${BLUE}Installing Xray/V2Ray...${NC}"
mkdir -p /usr/local/bin
curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /tmp/xray.zip
unzip /tmp/xray.zip -d /usr/local/bin
chmod +x /usr/local/bin/xray

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
echo -e "${BLUE}Issuing SSL with Let's Encrypt...${NC}"
certbot --nginx -d $DOMAIN -m $EMAIL --agree-tos --non-interactive
systemctl reload nginx

# ---------- Setup Monitoring ----------
echo -e "${BLUE}Setting up monitoring...${NC}"
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
echo -e "${BLUE}Setting up Telegram Bot...${NC}"
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
Built by IR-Devco
========================================
\e[0m"
