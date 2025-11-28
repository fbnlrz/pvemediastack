#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck | Modified by Fabi
# Author: tteck (tteckster) | Modified for combined installation
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Combined Media Stack: Sonarr + Radarr + Prowlarr + SABnzbd

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
msg_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

msg_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

msg_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   msg_error "This script must be run as root"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Combined Media Stack Installation"
echo "  Sonarr + Radarr + Prowlarr + SABnzbd"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Update system
msg_info "Updating system"
apt-get update &>/dev/null || msg_error "Failed to update system"
msg_ok "System updated"

# Install base dependencies
msg_info "Installing base dependencies"
apt-get install -y \
  curl \
  wget \
  sqlite3 \
  par2 \
  p7zip-full \
  ca-certificates \
  gnupg \
  python3 \
  python3-pip \
  python3-venv \
  git &>/dev/null || msg_error "Failed to install dependencies"
msg_ok "Base dependencies installed"

# ======================
# Create media user
# ======================
msg_info "Creating media user for permission management"
groupadd -g 1500 media 2>/dev/null || true
useradd -u 1500 -g media -m -s /bin/bash media 2>/dev/null || true
msg_ok "Media user created (UID: 1500, GID: 1500)"

# ======================
# SABnzbd Installation
# ======================
msg_info "Setting up Unrar for SABnzbd"
if [ -f /etc/os-release ]; then
    source /etc/os-release
    DEBIAN_CODENAME="${VERSION_CODENAME:-trixie}"
else
    DEBIAN_CODENAME="trixie"
fi

cat <<EOF >/etc/apt/sources.list.d/non-free.sources
Types: deb
URIs: http://deb.debian.org/debian/
Suites: ${DEBIAN_CODENAME}
Components: non-free 
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
apt-get update &>/dev/null
apt-get install -y unrar &>/dev/null || msg_error "Failed to install unrar"
msg_ok "Unrar installed"

msg_info "Installing SABnzbd"
mkdir -p /opt
cd /opt

# Clone SABnzbd
if [ -d "/opt/sabnzbd" ]; then
    rm -rf /opt/sabnzbd
fi
git clone --depth 1 https://github.com/sabnzbd/sabnzbd.git &>/dev/null || msg_error "Failed to clone SABnzbd"
cd sabnzbd

# Create virtual environment and install dependencies
python3 -m venv venv &>/dev/null || msg_error "Failed to create venv"
source venv/bin/activate
pip install --upgrade pip &>/dev/null
pip install -r requirements.txt &>/dev/null || msg_error "Failed to install SABnzbd requirements"
deactivate

# Set permissions
chown -R media:media /opt/sabnzbd
msg_ok "SABnzbd installed"

# Optional: par2cmdline-turbo
read -r -p "Would you like to install par2cmdline-turbo for faster repairs? (y/N): " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    msg_info "Installing par2cmdline-turbo"
    PAR2_VERSION=$(curl -s https://api.github.com/repos/animetosho/par2cmdline-turbo/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    wget -q "https://github.com/animetosho/par2cmdline-turbo/releases/download/${PAR2_VERSION}/par2cmdline-turbo-${PAR2_VERSION}-linux-amd64.zip" -O /tmp/par2.zip
    unzip -q /tmp/par2.zip -d /tmp/
    mv /usr/bin/par2 /usr/bin/par2.old 2>/dev/null || true
    mv /tmp/par2cmdline-turbo*/par2 /usr/bin/
    chmod +x /usr/bin/par2
    rm -rf /tmp/par2*
    msg_ok "par2cmdline-turbo installed"
fi

msg_info "Creating SABnzbd service"
cat <<EOF >/etc/systemd/system/sabnzbd.service
[Unit]
Description=SABnzbd
After=network.target

[Service]
WorkingDirectory=/opt/sabnzbd
ExecStart=/opt/sabnzbd/venv/bin/python SABnzbd.py -s 0.0.0.0:7777
Restart=always
User=media
Group=media

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now sabnzbd &>/dev/null || msg_error "Failed to start SABnzbd"
msg_ok "SABnzbd service created and started (Port 7777)"

# ======================
# Sonarr Installation
# ======================
msg_info "Installing Sonarr v4"
mkdir -p /var/lib/sonarr/
chown -R media:media /var/lib/sonarr/
chmod 775 /var/lib/sonarr/

cd /tmp
curl -fsSL "https://services.sonarr.tv/v1/download/main/latest?version=4&os=linux&arch=x64" -o "SonarrV4.tar.gz" || msg_error "Failed to download Sonarr"
tar -xzf SonarrV4.tar.gz
if [ -d "/opt/Sonarr" ]; then
    rm -rf /opt/Sonarr
fi
mv Sonarr /opt/
chown -R media:media /opt/Sonarr
rm -rf SonarrV4.tar.gz
msg_ok "Sonarr v4 installed"

msg_info "Creating Sonarr service"
cat <<EOF >/etc/systemd/system/sonarr.service
[Unit]
Description=Sonarr Daemon
After=syslog.target network.target

[Service]
Type=simple
User=media
Group=media
ExecStart=/opt/Sonarr/Sonarr -nobrowser -data=/var/lib/sonarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now sonarr &>/dev/null || msg_error "Failed to start Sonarr"
msg_ok "Sonarr service created and started (Port 8989)"

# ======================
# Radarr Installation
# ======================
msg_info "Installing Radarr"
mkdir -p /var/lib/radarr/
chown -R media:media /var/lib/radarr/
chmod 775 /var/lib/radarr/

cd /tmp
RADARR_VERSION=$(curl -s https://api.github.com/repos/Radarr/Radarr/releases/latest | grep -oP '"tag_name": "v\K[^"]*')
curl -fsSL "https://github.com/Radarr/Radarr/releases/download/v${RADARR_VERSION}/Radarr.master.${RADARR_VERSION}.linux-core-x64.tar.gz" -o "Radarr.tar.gz" || msg_error "Failed to download Radarr"
tar -xzf Radarr.tar.gz -C /opt/
chown -R media:media /opt/Radarr
chmod 775 /opt/Radarr/
rm -rf Radarr.tar.gz
msg_ok "Radarr installed"

msg_info "Creating Radarr service"
cat <<EOF >/etc/systemd/system/radarr.service
[Unit]
Description=Radarr Daemon
After=syslog.target network.target

[Service]
User=media
Group=media
UMask=0002
Type=simple
ExecStart=/opt/Radarr/Radarr -nobrowser -data=/var/lib/radarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now radarr &>/dev/null || msg_error "Failed to start Radarr"
msg_ok "Radarr service created and started (Port 7878)"

# ======================
# Prowlarr Installation
# ======================
msg_info "Installing Prowlarr"
mkdir -p /var/lib/prowlarr/
chown -R media:media /var/lib/prowlarr/
chmod 775 /var/lib/prowlarr/

cd /tmp
PROWLARR_VERSION=$(curl -s https://api.github.com/repos/Prowlarr/Prowlarr/releases/latest | grep -oP '"tag_name": "v\K[^"]*')
curl -fsSL "https://github.com/Prowlarr/Prowlarr/releases/download/v${PROWLARR_VERSION}/Prowlarr.master.${PROWLARR_VERSION}.linux-core-x64.tar.gz" -o "Prowlarr.tar.gz" || msg_error "Failed to download Prowlarr"
tar -xzf Prowlarr.tar.gz -C /opt/
chown -R media:media /opt/Prowlarr
chmod 775 /opt/Prowlarr/
rm -rf Prowlarr.tar.gz
msg_ok "Prowlarr installed"

msg_info "Creating Prowlarr service"
cat <<EOF >/etc/systemd/system/prowlarr.service
[Unit]
Description=Prowlarr Daemon
After=syslog.target network.target

[Service]
User=media
Group=media
UMask=0002
Type=simple
ExecStart=/opt/Prowlarr/Prowlarr -nobrowser -data=/var/lib/prowlarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now prowlarr &>/dev/null || msg_error "Failed to start Prowlarr"
msg_ok "Prowlarr service created and started (Port 9696)"

# ======================
# Final Summary
# ======================
IP=$(hostname -I | awk '{print $1}')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Media Stack Installation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Services installed and running:"
echo "  • SABnzbd:   http://${IP}:7777"
echo "  • Sonarr:    http://${IP}:8989"
echo "  • Radarr:    http://${IP}:7878"
echo "  • Prowlarr:  http://${IP}:9696"
echo ""
echo "  Next steps:"
echo "  1. Configure SABnzbd with your Usenet provider"
echo "  2. Set download paths in SABnzbd"
echo "  3. Add SABnzbd as download client in Prowlarr"
echo "  4. Connect Prowlarr to Sonarr and Radarr"
echo "  5. Configure your media root folders"
echo ""
echo "  Notes:"
echo "  • All services run as user: media (UID: 1500)"
echo "  • For NFS/CIFS mounts, ensure permissions for UID/GID: 1500"
echo ""
echo "  Check service status:"
echo "  systemctl status sabnzbd sonarr radarr prowlarr"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
