# 🔧 Update v1.1.0 - Standalone Version

## Was wurde geändert?

### Problem
Die ursprünglichen Scripts verwendeten Funktionen vom Community Scripts Framework:
- `msg_info`, `msg_ok`, `msg_error` → Fehlermeldungen
- `setup_uv` → UV/Python Setup
- `fetch_and_deploy_gh_release` → GitHub Release Downloads
- `$STD` → Silent execution
- `motd_ssh`, `customize`, `cleanup_lxc` → Container Customization

Diese Funktionen sind nur verfügbar wenn man das `build.func` Script sourced - was zu Dependency-Problemen führte.

### Lösung

**Beide Scripts sind jetzt 100% eigenständig:**

#### mediastack-install.sh
- ✅ Eigene Helper Functions (`msg_info`, `msg_ok`, `msg_error`)
- ✅ Direkter Download von Releases (ohne `fetch_and_deploy_gh_release`)
- ✅ Native Python venv (statt UV)
- ✅ Git Clone für SABnzbd (stabiler als Releases)
- ✅ Manuelle API Calls für Radarr Version

#### mediastack.sh
- ✅ Kein `source <(curl ...)` mehr
- ✅ Native `pct` Befehle
- ✅ Eigene Container-Logik
- ✅ Command-line Options Support

---

## Installation - Neu

### Automatisch (empfohlen)
```bash
bash <(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack.sh)
```

### Manuell (in bestehendem Container)
```bash
bash <(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack-install.sh)
```

---

## Was funktioniert jetzt?

### ✅ Funktioniert
- Debian 13 Container Erstellung
- SABnzbd Installation via Git Clone
- Sonarr v4 Installation
- Radarr Installation
- Service Creation & Auto-Start
- Media User (UID: 1500)
- Optionales par2cmdline-turbo

### ⚠️ Bekannte Änderungen

**SABnzbd:**
- Verwendet jetzt Git Clone statt Release Tarball
- Installiert immer neueste Entwickler-Version
- Bei Problemen: Fixe auf stable Tag mit `cd /opt/sabnzbd && git checkout <version>`

**Python venv:**
- Verwendet natives Python venv statt UV
- Etwas langsamer aber stabiler
- Vollständig kompatibel

**Kein Cleanup:**
- Script macht kein `cleanup_lxc` mehr
- Container ist sofort nutzbar
- Keine zusätzlichen Optimierungen

---

## Migration von v1.0

Falls du bereits einen Container mit v1.0 hast:

### Option 1: Neu installieren (empfohlen)
```bash
# Alten Container löschen
pct stop <old-id>
pct destroy <old-id>

# Neu installieren mit v1.1
bash <(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack.sh)
```

### Option 2: In-Place Update (experimentell)
```bash
# Im Container
systemctl stop sabnzbd sonarr radarr

# Update Scripts holen
cd /opt
rm -rf sabnzbd Sonarr Radarr

# Neu installieren
bash <(wget -qLO - https://raw.githubusercontent.com/fbnlrz/pvemediastack/main/mediastack-install.sh)
```

---

## Testing Checklist

Nach der Installation prüfen:

```bash
# Services Status
systemctl status sabnzbd sonarr radarr

# Ports Check
netstat -tulpn | grep -E "7777|8989|7878"

# Web UIs
curl -I http://localhost:7777
curl -I http://localhost:8989
curl -I http://localhost:7878

# Media User
id media  # Should show UID 1500, GID 1500
```

Alle sollten erfolgreich sein!

---

## Bekannte Issues

### SABnzbd Git vs Release
- **Issue:** Git Clone kann instabil sein bei Breaking Changes
- **Fix:** Pin auf stable Tag wenn nötig
  ```bash
  cd /opt/sabnzbd
  git fetch --tags
  git checkout 4.4.0  # oder aktuelle stable version
  systemctl restart sabnzbd
  ```

### Python Dependencies
- **Issue:** Manche Python Packages brauchen Compiler
- **Fix:** Bereits inkludiert via `python3-pip`

### Erste Installation langsam
- **Issue:** Erster Start kann 1-2 Minuten dauern
- **Grund:** Python venv muss alle Packages installieren
- **Normal:** Das ist expected behavior

---

## Changelog v1.0 → v1.1

### Added
- Standalone Installation ohne externe Dependencies
- Color-coded Output (INFO/OK/ERROR)
- Better error handling
- Git-based SABnzbd installation
- Direct API calls for version checking

### Changed
- Removed dependency on Community Scripts build.func
- Switched from UV to native Python venv
- Simplified download logic
- Better progress indicators

### Removed
- External function dependencies
- UV dependency
- Container customization hooks

### Fixed
- 404 errors when running mediastack.sh
- "command not found" errors in install script
- Dependency on external framework

---

## Upgrade Path

**Von v1.0.x → v1.1.0:**
Empfohlen: Neu installieren (Configs können via Backup gesichert werden)

**Zukünftige Updates:**
Updates werden backward compatible sein - simple re-run of install script

---

## Support

Bei Problemen:
1. Prüfe die [Testing Guide](TESTING.md)
2. Öffne ein [GitHub Issue](https://github.com/fbnlrz/pvemediastack/issues)
3. Include:
   - Proxmox Version
   - Container ID
   - Error Messages
   - Output von `systemctl status sabnzbd sonarr radarr`

---

**Version:** 1.1.0  
**Release Date:** 2024-11-22  
**Status:** Stable
