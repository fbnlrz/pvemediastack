#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck | Modified by Fabi
# Author: tteck (tteckster) | Modified for combined media stack
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Combined Media Stack: Sonarr + Radarr + Prowlarr + SABnzbd
# Wrapper script to create LXC and install applications

INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack-install.sh"

function header_info {
  clear
  cat <<"EOF"
    __  ___          ___         ______           __  
   /  |/  /__  ____/ (_)__ _   / __/ /____ _____/ /__
  / /|_/ / _ \/ __  / / _ `/  _\ \/ __/ _ `/ __/  '_/
 /_/  /_/\___/\___/_/\_, /  /___/\__/\_,_/\__/_/\_\ 
                    /___/                            
 
 Combined: Sonarr + Radarr + Prowlarr + SABnzbd
EOF
}

# Helper functions
msg_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

msg_ok() {
    echo -e "\033[0;32m[OK]\033[0m $1"
}

msg_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
    exit 1
}

header_info
echo -e "\n Loading..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   msg_error "This script must be run as root"
fi

# Check if running on Proxmox VE
if ! command -v pct >/dev/null; then
    msg_error "This script must be run on a Proxmox VE host."
fi

# Default values
CTID=""
HOSTNAME="mediastack"
STORAGE="local"
ROOTFS_STORAGE="local-lvm"
ROOTFS_SIZE="18"
MEMORY="2048"
CORES="2"
UNPRIVILEGED="1"
START_ON_BOOT="0"
BRIDGE="vmbr0"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--storage)
            STORAGE="$2"
            shift 2
            ;;
        -r|--rootfs-storage)
            ROOTFS_STORAGE="$2"
            shift 2
            ;;
        -c|--cores)
            CORES="$2"
            shift 2
            ;;
        -m|--memory)
            MEMORY="$2"
            shift 2
            ;;
        -d|--disk)
            ROOTFS_SIZE="$2"
            shift 2
            ;;
        -h|--hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        -i|--id)
            CTID="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -i, --id            Container ID (auto-assigned if not specified)"
            echo "  -h, --hostname      Hostname (default: mediastack)"
            echo "  -m, --memory        RAM in MB (default: 2048)"
            echo "  -c, --cores         CPU cores (default: 2)"
            echo "  -d, --disk          Disk size in GB (default: 18)"
            echo "  -s, --storage       Template storage (default: local)"
            echo "  -r, --rootfs-storage Rootfs storage (default: local-lvm)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Auto-assign CTID if not specified
if [[ -z "$CTID" ]]; then
    CTID=$(pvesh get /cluster/nextid)
fi

echo "Creating LXC Container with:"
echo "  ID: $CTID"
echo "  Hostname: $HOSTNAME"
echo "  Memory: ${MEMORY}MB"
echo "  Cores: $CORES"
echo "  Disk: ${ROOTFS_SIZE}GB"
echo ""

# Find/Download Template
msg_info "Updating template list..."
pveam update >/dev/null 2>&1 || true

msg_info "Selecting Debian template..."
# Try to find Debian 13, fallback to Debian 12
TEMPLATE=$(pveam available --section system | awk '{print $2}' | grep "debian-13-standard" | sort -r | head -n 1)
if [[ -z "$TEMPLATE" ]]; then
    TEMPLATE=$(pveam available --section system | awk '{print $2}' | grep "debian-12-standard" | sort -r | head -n 1)
fi

if [[ -z "$TEMPLATE" ]]; then
    msg_error "No suitable Debian template found in 'pveam available'. Please ensure you have internet access and configured repositories."
fi

msg_ok "Selected template: $TEMPLATE"

# Check if template is already downloaded
if ! pveam list $STORAGE | grep -q "$TEMPLATE"; then
    msg_info "Downloading template to $STORAGE..."
    pveam download $STORAGE $TEMPLATE >/dev/null || msg_error "Failed to download template"
    msg_ok "Template downloaded"
else
    msg_ok "Template already available on $STORAGE"
fi

# Create container
msg_info "Creating container $CTID..."
pct create $CTID ${STORAGE}:vztmpl/${TEMPLATE} \
    --hostname $HOSTNAME \
    --cores $CORES \
    --memory $MEMORY \
    --rootfs ${ROOTFS_STORAGE}:${ROOTFS_SIZE} \
    --net0 name=eth0,bridge=${BRIDGE},ip=dhcp \
    --unprivileged $UNPRIVILEGED \
    --features nesting=1 \
    --onboot $START_ON_BOOT \
    --start 1 >/dev/null || msg_error "Failed to create container"

msg_ok "Container created and started"

# Wait for container to be ready
msg_info "Waiting for container to initialize..."
MAX_WAIT=30
WAITED=0
while ! pct exec $CTID -- test -f /bin/bash 2>/dev/null; do
    if [ $WAITED -ge $MAX_WAIT ]; then
        msg_error "Container failed to start properly or is not reachable"
    fi
    sleep 1
    ((WAITED++))
done
sleep 2 # Extra buffer

msg_ok "Container is ready"
msg_info "Running installation script inside container..."

# Run installation script
pct exec $CTID -- bash -c "$(wget -qLO - ${INSTALL_SCRIPT_URL})" || {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ❌ Installation failed!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Container $CTID has been created but the installation script returned an error."
    echo "  You can debug by entering the container:"
    echo "    pct enter $CTID"
    echo "  And running the script manually:"
    echo "    bash <(wget -qLO - ${INSTALL_SCRIPT_URL})"
    exit 1
}

# Get container IP
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ✅ Media Stack has been installed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " Container ID: $CTID"
echo " Hostname: $HOSTNAME"
echo " IP Address: $IP"
echo ""
echo " Access your services at:"
echo " • SABnzbd:   http://${IP}:7777"
echo " • Sonarr:    http://${IP}:8989"
echo " • Radarr:    http://${IP}:7878"
echo " • Prowlarr:  http://${IP}:9696"
echo ""
echo " Configuration:"
echo " 1. Configure SABnzbd with your Usenet provider"
echo " 2. Set download paths in SABnzbd"
echo " 3. Add SABnzbd as download client in Prowlarr"
echo " 4. Connect Prowlarr to Sonarr and Radarr"
echo " 5. Configure your media paths in Sonarr/Radarr"
echo ""
echo " Management:"
echo " • Enter container: pct enter $CTID"
echo " • Stop container:  pct stop $CTID"
echo " • Start container: pct start $CTID"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
