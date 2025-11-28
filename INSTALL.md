# 🚀 Einfache Installation - Schritt für Schritt

## Variante 1: Automatisch (Empfohlen)

Führe dies auf deinem **Proxmox Host** aus:

```bash
bash <(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack.sh)
```

Das war's! Das Script:
1. Erstellt einen Debian 13 LXC Container
2. Installiert alle drei Services automatisch
3. Zeigt dir am Ende die URLs

---

## Variante 2: Manuelle Container-Erstellung

Falls du mehr Kontrolle möchtest:

### Schritt 1: Container erstellen

```bash
# Auf dem Proxmox Host
pct create 100 local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname mediastack \
  --memory 2048 \
  --cores 2 \
  --rootfs local-lvm:18 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --features nesting=1 \
  --start 1
```

**Hinweis:** Passe die Container-ID (100) und Storage-Namen (local, local-lvm) an deine Umgebung an!

### Schritt 2: In Container wechseln

```bash
pct enter 100
```

### Schritt 3: Installation starten

```bash
bash <(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack-install.sh)
```

### Schritt 4: Installation läuft...

Die Installation dauert **5-10 Minuten**. Du siehst:
- ✓ Installation von Dependencies
- ✓ SABnzbd Setup
- ✓ Sonarr Installation  
- ✓ Radarr Installation
- ✓ Service Creation

### Schritt 5: IP-Adresse herausfinden

```bash
hostname -I
```

### Schritt 6: Services aufrufen

In deinem Browser:
- SABnzbd: `http://<ip>:7777`
- Sonarr: `http://<ip>:8989`
- Radarr: `http://<ip>:7878`

---

## Variante 3: Mit Custom Settings

### Storage anpassen

Falls du andere Storage-Namen hast:

```bash
# Verfügbare Storages anzeigen
pvesm status

# Template Storage prüfen
pveam available | grep debian-13

# Mit custom Storage
bash <(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack.sh) \
  -s local \
  -r local-lvm
```

### Mehr Ressourcen

```bash
bash <(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack.sh) \
  -m 4096 \
  -c 4 \
  -d 25
```

- `-m` = RAM in MB (z.B. 4096 = 4GB)
- `-c` = CPU Cores (z.B. 4)
- `-d` = Disk Size in GB (z.B. 25)

### Feste Container-ID

```bash
bash <(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack.sh) -i 200
```

### Alle Optionen

```bash
bash <(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack.sh) --help
```

---

## Nach der Installation

### Services prüfen

```bash
# Im Container
systemctl status sabnzbd sonarr radarr
```

### Logs ansehen

```bash
journalctl -u sabnzbd -f    # SABnzbd logs
journalctl -u sonarr -f     # Sonarr logs
journalctl -u radarr -f     # Radarr logs
```

### Container-Befehle

```bash
# Auf Proxmox Host
pct start 100      # Container starten
pct stop 100       # Container stoppen
pct enter 100      # In Container wechseln
pct list           # Alle Container anzeigen
```

---

## Troubleshooting

### Template nicht gefunden

```bash
# Template herunterladen
pveam update
pveam download local debian-13-standard_13.1-2_amd64.tar.zst
```

### Container startet nicht

```bash
# Status prüfen
pct status 100

# Logs prüfen
pct exec 100 -- journalctl -xe
```

### Installation schlägt fehl

```bash
# Manuell im Container versuchen
pct enter 100

# Netzwerk prüfen
ping google.com

# Updates prüfen
apt update

# Installation manuell starten
bash <(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack-install.sh)
```

### Services laufen nicht

```bash
# Im Container
systemctl restart sabnzbd sonarr radarr
systemctl status sabnzbd sonarr radarr
```

---

## Nächste Schritte

1. **SABnzbd konfigurieren** (Port 7777)
   - Usenet Provider hinzufügen
   - Download-Pfade setzen
   - API Key notieren

2. **Sonarr konfigurieren** (Port 8989)
   - Download Client: SABnzbd (localhost:7777)
   - Root Folder: `/media/tv` (z.B.)
   - Indexer hinzufügen

3. **Radarr konfigurieren** (Port 7878)
   - Download Client: SABnzbd (localhost:7777)
   - Root Folder: `/media/movies` (z.B.)
   - Indexer hinzufügen

4. **Storage mounten** (optional)
   - Siehe Hauptdokumentation für NFS/CIFS Mounts

---

## Quick Links

- 📖 [Vollständige Dokumentation](README.md)
- 🧪 [Testing Guide](TESTING.md)
- 🐛 [GitHub Issues](https://github.com/fbnlrz/pvemediastack/issues)
- 💬 [Discussions](https://github.com/fbnlrz/pvemediastack/discussions)

---

**Viel Erfolg! 🎬**
