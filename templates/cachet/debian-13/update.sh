#!/bin/bash
# templates/nginx/update.sh
# In-container update script for nginx template
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

readonly COMMAND="${1:-}"
readonly BACKUP_PATH="${BACKUP_PATH:-/var/backups/template-update/current}"

# === Functions ===
do_backup() {
	mkdir -p "$BACKUP_PATH"

	# Backup nginx config
	if [[ -d /etc/nginx ]]; then
		cp -r /etc/nginx "$BACKUP_PATH/"
	fi

	# Backup website
	if [[ -d /var/www/html ]]; then
		cp -r /var/www/html "$BACKUP_PATH/"
	fi

	echo "Backup completed"
}

do_update() {
	# Update system packages
	apt-get update
	apt-get upgrade -y

	# Restart nginx if config is valid
	if nginx -t 2>/dev/null; then
		systemctl restart nginx
	fi

	echo "Update completed"
}

do_rollback() {
	# Restore nginx config
	if [[ -d "$BACKUP_PATH/nginx" ]]; then
		rm -rf /etc/nginx
		cp -r "$BACKUP_PATH/nginx" /etc/
	fi

	# Restore website
	if [[ -d "$BACKUP_PATH/html" ]]; then
		rm -rf /var/www/html
		cp -r "$BACKUP_PATH/html" /var/www/
	fi

	# Restart nginx
	if nginx -t 2>/dev/null; then
		systemctl restart nginx
	fi

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
