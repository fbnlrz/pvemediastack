#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck | Modified by Fabi
# Author: tteck (tteckster) | Modified for combined media stack
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Combined Media Stack: Sonarr + Radarr + SABnzbd
# Wrapper script to create LXC and install applications

function header_info {
  clear
  cat <<"EOF"
    __  ___          ___         ______           __  
   /  |/  /__  ____/ (_)__ _   / __/ /____ _____/ /__
  / /|_/ / _ \/ __  / / _ `/  _\ \/ __/ _ `/ __/  '_/
 /_/  /_/\___/\___/_/\_, /  /___/\__/\_,_/\__/_/\_\ 
                    /___/                            
 
 Combined: Sonarr + Radarr + SABnzbd
EOF
}

header_info
echo -e "\n Loading..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Default values
CTID=""
HOSTNAME="mediastack"
TEMPLATE="debian-13-standard_13.1-2_amd64.tar.zst"
STORAGE="local"
ROOTFS_STORAGE="local-lvm"
ROOTFS_SIZE="18"
MEMORY="2048"
CORES="2"
PASSWORD=""
SSH_KEY=""
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

# Check if template exists
if ! pveam list $STORAGE | grep -q "$TEMPLATE"; then
    echo "Template $TEMPLATE not found in storage $STORAGE"
    echo "Downloading template..."
    pveam download $STORAGE $TEMPLATE || {
        echo "Failed to download template"
        exit 1
    }
fi

# Create container
echo "Creating container..."
pct create $CTID ${STORAGE}:vztmpl/${TEMPLATE} \
    --hostname $HOSTNAME \
    --cores $CORES \
    --memory $MEMORY \
    --rootfs ${ROOTFS_STORAGE}:${ROOTFS_SIZE} \
    --net0 name=eth0,bridge=${BRIDGE},ip=dhcp \
    --unprivileged $UNPRIVILEGED \
    --features nesting=1 \
    --onboot $START_ON_BOOT \
    --start 1 || {
        echo "Failed to create container"
        exit 1
    }

echo "Container created successfully!"
echo "Waiting for container to start..."
sleep 5

# Wait for container to be ready
MAX_WAIT=30
WAITED=0
while ! pct exec $CTID -- test -f /bin/bash 2>/dev/null; do
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo "Container failed to start properly"
        exit 1
    fi
    sleep 1
    ((WAITED++))
done

echo "Container is ready!"
echo "Running installation script..."
echo ""

# Run installation script
pct exec $CTID -- bash -c "$(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack-install.sh)" || {
    echo "Installation failed!"
    echo "Container $CTID has been created but installation was not successful."
    echo "You can manually run the installation with:"
    echo "  pct enter $CTID"
    echo "  bash <(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack-install.sh)"
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
echo " • SABnzbd:  http://${IP}:7777"
echo " • Sonarr:   http://${IP}:8989"
echo " • Radarr:   http://${IP}:7878"
echo ""
echo " Configuration:"
echo " 1. Configure SABnzbd with your Usenet provider"
echo " 2. Set download paths in SABnzbd"
echo " 3. Add SABnzbd as download client in Sonarr/Radarr"
echo " 4. Configure your media paths in Sonarr/Radarr"
echo ""
echo " Enter container: pct enter $CTID"
echo " Stop container: pct stop $CTID"
echo " Start container: pct start $CTID"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

