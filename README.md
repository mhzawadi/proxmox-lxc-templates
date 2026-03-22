# Proxmox LXC Templates

Custom LXC container templates for Proxmox VE. Pre-configured, optimized, and ready to deploy.

[![Build](https://github.com/mhzawadi/proxmox-lxc-templates/actions/workflows/build-debian-13.yml/badge.svg)](https://github.com/mhzawadi/proxmox-lxc-templates/actions/workflows/build-debian-13.yml)
[![License](https://img.shields.io/github/license/mhzawadi/proxmox-lxc-templates)](LICENSE)

## Overview

This project provides production-ready LXC container templates built with GitHub Actions using `debootstrap`. All templates are based on **Debian 13 (Trixie)** and include:

- SHA-512 verified downloads
- Built-in update mechanism with rollback support
- Consistent UID/GID mapping for shared storage
- Minimal footprint with only required packages

**Website:** https://mhzawadi.github.io/proxmox-lxc-templates/

## Available Templates

| Template | Description | Version |
|----------|-------------|---------|
| [Shoko](https://mhzawadi.github.io/proxmox-lxc-templates/#shoko) | Anime Server | 5.1.0 |
| [Nginx Proxy Manager](https://mhzawadi.github.io/proxmox-lxc-templates/#nginx-proxy-manager) | Reverse Proxy | 2.13.5 |
| [JDownloader](https://mhzawadi.github.io/proxmox-lxc-templates/#jdownloader) | Download Manager | 2.0 |
| [ecoDMS](https://mhzawadi.github.io/proxmox-lxc-templates/#ecodms) | Document Management | 25.02 |
| [Jellyfin](https://mhzawadi.github.io/proxmox-lxc-templates/#jellyfin) | Media Server | 10.11.6 |
| [Nginx](https://mhzawadi.github.io/proxmox-lxc-templates/#nginx) | Web Server | 1.28.2 |
| [Nextcloud](https://mhzawadi.github.io/proxmox-lxc-templates/#nextcloud) | cloud storage | 32.0.6 |

## Installation

### Web UI

1. Navigate to **Datacenter** > **Storage** > **local** > **CT Templates**
2. Click **Download from URL**
3. Copy the URL and SHA-512 checksum from the [website](https://mhzawadi.github.io/proxmox-lxc-templates/)
4. Paste both values and click **Query URL** then **Download**

### CLI

```bash
pvesh create /nodes/$(hostname)/storage/local/download-url \
  --content vztmpl \
  --filename <FILENAME> \
  --url <URL> \
  --checksum <SHA512> \
  --checksum-algorithm sha512
```

Get the complete command with all values from the [website](https://mhzawadi.github.io/proxmox-lxc-templates/).

## Update Containers

Every template includes `template-update` for in-place updates:

```bash
template-update status      # Check current version and available updates
template-update update      # Download and apply update
template-update rollback    # Restore previous version from backup
template-update changelog   # View changelog
template-update history     # Show update history
```

## Shared Storage

Templates use consistent UID/GID mapping for shared storage access:

| Category | GID | Description |
|----------|-----|-------------|
| media | 1100 | Jellyfin, Shoko, JDownloader |
| network | 1200 | Nginx, Nginx Proxy Manager |
| storage | 1600 | ecoDMS |

Mount shared storage with matching group ownership to enable access across containers.

## Contributing

1. Fork the repository
2. Create a template directory: `templates/<name>/debian-13/`
3. Add required files: `config.yml`, `build.sh`, `update.sh`, `CHANGELOG.md`
4. Submit a pull request

See existing templates for reference.

## License

[MIT](LICENSE)
