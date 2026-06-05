#!/bin/bash
# templates/vaultwarden/update.sh
# In-container update script for Vaultwarden template
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

readonly COMMAND="${1:-}"
readonly BACKUP_PATH="${BACKUP_PATH:-/var/backups/template-update/current}"
readonly BINARY_REPO="https://github.com/czyt/vaultwarden-binary/releases/download"

# === Functions ===
get_current_version() {
	if [[ -f /etc/template-info ]]; then
		local version
		version=$(grep '^TEMPLATE_VERSION=' /etc/template-info | cut -d'"' -f2)
		echo "${version%-*}"
	else
		echo "unknown"
	fi
}

get_latest_version() {
	local version
	version=$(curl -fsSL "https://api.github.com/repos/czyt/vaultwarden-binary/releases/latest" \
		| grep -oP '"tag_name":\s*"\K[^"]+' \
		| sed 's/-extracted$//')

	if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		echo "Error: Failed to get latest version" >&2
		return 1
	fi
	echo "$version"
}

do_backup() {
	mkdir -p "$BACKUP_PATH"

	# Backup binary
	if [[ -f /usr/local/bin/vaultwarden ]]; then
		cp /usr/local/bin/vaultwarden "$BACKUP_PATH/"
	fi

	# Backup web vault
	if [[ -d /usr/share/vaultwarden/web-vault ]]; then
		cp -r /usr/share/vaultwarden/web-vault "$BACKUP_PATH/"
	fi

	# Backup configuration
	if [[ -d /etc/vaultwarden ]]; then
		cp -r /etc/vaultwarden "$BACKUP_PATH/"
	fi

	# Backup data
	if [[ -d /var/lib/vaultwarden ]]; then
		cp -r /var/lib/vaultwarden "$BACKUP_PATH/"
	fi

	echo "Backup completed to $BACKUP_PATH"
}

do_update() {
	local current_version
	local latest_version
	local download_url

	current_version=$(get_current_version)
	latest_version=$(get_latest_version) || exit 1

	# Create backup before update
	echo "Creating backup before update..."
	do_backup

	if [[ "$current_version" == "$latest_version" ]]; then
		echo "Already at latest version: $current_version"
		return 0
	fi

	echo "Updating from $current_version to $latest_version..."

	download_url="${BINARY_REPO}/${latest_version}-extracted/vaultwarden-linux-amd64-extracted.zip"

	# Download new version
	cd /var/tmp
	curl -fsSL -o vaultwarden.zip "$download_url"
	unzip -q vaultwarden.zip

	# Stop service
	systemctl stop vaultwarden

	# Install new binary
	install -m 755 vaultwarden /usr/local/bin/vaultwarden

	# Update web vault
	rm -rf /usr/share/vaultwarden/web-vault
	cp -r web-vault /usr/share/vaultwarden/

	# Cleanup
	rm -rf vaultwarden.zip vaultwarden web-vault

	# Update template info
	if [[ -f /etc/template-info ]]; then
		sed -i "s/^TEMPLATE_VERSION=.*/TEMPLATE_VERSION=\"${latest_version}-1\"/" /etc/template-info
	fi

	# Start service
	systemctl start vaultwarden

	echo "Update completed: $current_version -> $latest_version"
}

do_rollback() {
	if [[ ! -d "$BACKUP_PATH" ]]; then
		echo "Error: No backup found at $BACKUP_PATH"
		exit 1
	fi

	echo "Rolling back from backup..."

	# Stop service
	systemctl stop vaultwarden

	# Restore binary
	if [[ -f "$BACKUP_PATH/vaultwarden" ]]; then
		cp "$BACKUP_PATH/vaultwarden" /usr/local/bin/vaultwarden
		chmod 755 /usr/local/bin/vaultwarden
	fi

	# Restore web vault
	if [[ -d "$BACKUP_PATH/web-vault" ]]; then
		rm -rf /usr/share/vaultwarden/web-vault
		cp -r "$BACKUP_PATH/web-vault" /usr/share/vaultwarden/
	fi

	# Restore configuration
	if [[ -d "$BACKUP_PATH/vaultwarden" ]]; then
		cp -r "$BACKUP_PATH/vaultwarden/"* /etc/vaultwarden/
	fi

	# Start service
	systemctl start vaultwarden

	echo "Rollback completed"
}

# === Main ===
case "$COMMAND" in
backup) do_backup ;;
update) do_update ;;
rollback) do_rollback ;;
*)
	echo "Usage: $0 {backup|update|rollback}"
	exit 1
	;;
esac
