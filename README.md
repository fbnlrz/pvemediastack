# Proxmox VE Media Stack (LXC)

A streamlined, automated script to deploy a complete media stack in a Proxmox VE LXC container. This stack includes **SABnzbd**, **Sonarr**, **Radarr**, and **Prowlarr**, all configured to run securely.

## 🚀 Features

*   **Automated Deployment**: Creates an LXC container and installs all software in one go.
*   **Comprehensive Stack**:
    *   **[SABnzbd](https://sabnzbd.org/)**: Usenet binary newsreader.
    *   **[Sonarr](https://sonarr.tv/)**: Smart TV show PVR.
    *   **[Radarr](https://radarr.video/)**: Movie collection manager.
    *   **[Prowlarr](https://prowlarr.com/)**: Indexer manager/proxy.
*   **Secure by Design**: All services run as a dedicated unprivileged user (`media`, UID: 1500), not as root.
*   **Dynamic Compatibility**: Automatically detects and uses the latest available Debian template (Debian 13 or 12).
*   **Lightweight**: Uses a minimal Debian base.

## 🛠️ Installation

Run the following command in your Proxmox VE shell:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack.sh)"
```

### Installation Options

The script accepts various arguments to customize the container:

```bash
./mediastack.sh --id 105 --hostname my-media --memory 4096 --cores 4 --disk 50
```

| Option | Description | Default |
| :--- | :--- | :--- |
| `-i`, `--id` | Container ID | Auto-assigned |
| `-h`, `--hostname` | Container Hostname | `mediastack` |
| `-m`, `--memory` | RAM in MB | `2048` |
| `-c`, `--cores` | CPU Cores | `2` |
| `-d`, `--disk` | Disk Size in GB | `18` |
| `-s`, `--storage` | Template Storage | `local` |
| `-r`, `--rootfs-storage` | Rootfs Storage | `local-lvm` |

## 📊 Accessing Services

Once installation is complete, you can access the services via your browser at the container's IP address:

| Service | Port | URL |
| :--- | :--- | :--- |
| **SABnzbd** | 7777 | `http://<IP>:7777` |
| **Radarr** | 7878 | `http://<IP>:7878` |
| **Sonarr** | 8989 | `http://<IP>:8989` |
| **Prowlarr** | 9696 | `http://<IP>:9696` |

## ⚙️ Configuration

### File Permissions
All services run as the user `media` with UID/GID **1500**.
*   **Internal Data**: `/var/lib/{sonarr,radarr,prowlarr}` and `/opt/sabnzbd`
*   **External Storage**: If you mount external storage (NAS, bind mounts), ensure the `media` user (UID 1500) has read/write permissions on those directories.

### Directories
*   **Installation Directory**: `/opt/`
*   **Data Directory**: `/var/lib/` (for *arr apps)

## 🤝 Credits

*   Originally based on scripts by [tteck](https://github.com/tteck/Proxmox).
*   Modified and maintained for this combined stack.

## 📄 License
MIT License
