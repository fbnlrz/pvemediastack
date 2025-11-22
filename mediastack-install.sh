#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck | Modified by Fabi
# Author: tteck (tteckster) | Modified for combined installation
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Combined Media Stack: Sonarr + Radarr + SABnzbd

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Base Dependencies"
$STD apt install -y \
  sqlite3 \
  par2 \
  p7zip-full
msg_ok "Installed Base Dependencies"

PYTHON_VERSION="3.13" setup_uv

# ======================
# SABnzbd Installation
# ======================
msg_info "Setting up Unrar for SABnzbd"
cat <<EOF >/etc/apt/sources.list.d/non-free.sources
Types: deb
URIs: http://deb.debian.org/debian/
Suites: trixie
Components: non-free 
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
$STD apt update
$STD apt install -y unrar
msg_ok "Setup Unrar"

msg_info "Installing SABnzbd"
fetch_and_deploy_gh_release "sabnzbd-org" "sabnzbd/sabnzbd" "prebuild" "latest" "/opt/sabnzbd" "SABnzbd-*-src.tar.gz"
$STD uv venv /opt/sabnzbd/venv
$STD uv pip install -r /opt/sabnzbd/requirements.txt --python=/opt/sabnzbd/venv/bin/python
msg_ok "Installed SABnzbd"

read -r -p "Would you like to install par2cmdline-turbo? <y/N> " prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
  mv /usr/bin/par2 /usr/bin/par2.old
  fetch_and_deploy_gh_release "par2cmdline-turbo" "animetosho/par2cmdline-turbo" "prebuild" "latest" "/usr/bin/" "*-linux-amd64.zip"
fi

msg_info "Creating SABnzbd Service"
cat <<EOF >/etc/systemd/system/sabnzbd.service
[Unit]
Description=SABnzbd
After=network.target

[Service]
WorkingDirectory=/opt/sabnzbd
ExecStart=/opt/sabnzbd/venv/bin/python SABnzbd.py -s 0.0.0.0:7777
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now sabnzbd
msg_ok "Created SABnzbd Service (Port 7777)"

# ======================
# Sonarr Installation
# ======================
msg_info "Installing Sonarr v4"
mkdir -p /var/lib/sonarr/
chmod 775 /var/lib/sonarr/
curl -fsSL "https://services.sonarr.tv/v1/download/main/latest?version=4&os=linux&arch=x64" -o "SonarrV4.tar.gz"
tar -xzf SonarrV4.tar.gz
mv Sonarr /opt
rm -rf SonarrV4.tar.gz
msg_ok "Installed Sonarr v4"

msg_info "Creating Sonarr Service"
cat <<EOF >/etc/systemd/system/sonarr.service
[Unit]
Description=Sonarr Daemon
After=syslog.target network.target
[Service]
Type=simple
ExecStart=/opt/Sonarr/Sonarr -nobrowser -data=/var/lib/sonarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now sonarr
msg_ok "Created Sonarr Service (Port 8989)"

# ======================
# Radarr Installation
# ======================
msg_info "Installing Radarr"
fetch_and_deploy_gh_release "Radarr" "Radarr/Radarr" "prebuild" "latest" "/opt/Radarr" "Radarr.master*linux-core-x64.tar.gz"
mkdir -p /var/lib/radarr/
chmod 775 /var/lib/radarr/ /opt/Radarr/
msg_ok "Installed Radarr"

msg_info "Creating Radarr Service"
cat <<EOF >/etc/systemd/system/radarr.service
[Unit]
Description=Radarr Daemon
After=syslog.target network.target

[Service]
UMask=0002
Type=simple
ExecStart=/opt/Radarr/Radarr -nobrowser -data=/var/lib/radarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now radarr
msg_ok "Created Radarr Service (Port 7878)"

# ======================
# Summary
# ======================
msg_info "Creating shared media user (optional setup)"
# Create a common media user for better permission management
groupadd -g 1500 media 2>/dev/null || true
useradd -u 1500 -g media -m -s /bin/bash media 2>/dev/null || true
msg_ok "Media user created (UID: 1500, GID: 1500)"

motd_ssh
customize
cleanup_lxc

# Display summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Media Stack Installation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Services installed and running:"
echo "  • SABnzbd:  http://$(hostname -I | awk '{print $1}'):7777"
echo "  • Sonarr:   http://$(hostname -I | awk '{print $1}'):8989"
echo "  • Radarr:   http://$(hostname -I | awk '{print $1}'):7878"
echo ""
echo "  Notes:"
echo "  • All services run as root by default"
echo "  • A 'media' user (UID: 1500) has been created"
echo "  • For NFS/CIFS mounts, consider using the media user"
echo "  • Configure download paths in SABnzbd first"
echo "  • Point Sonarr/Radarr to SABnzbd as download client"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
