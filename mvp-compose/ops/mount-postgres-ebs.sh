#!/usr/bin/env bash
set -euo pipefail

DEVICE="${DEVICE:-/dev/xvdb}"
MOUNTPOINT="${MOUNTPOINT:-/var/lib/postgresql/data}"

log() {
  printf '[mount-postgres-ebs] %s\n' "$*"
}

require_binary() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "missing dependency: $1"
    exit 1
  fi
}

require_binary lsblk
require_binary blkid

if [ ! -b "$DEVICE" ]; then
  log "device $DEVICE not found; set DEVICE=/dev/xyz before running"
  exit 1
fi

sudo mkdir -p "$MOUNTPOINT"

if ! sudo blkid "$DEVICE" >/dev/null 2>&1; then
  log "formatting $DEVICE as ext4 (first-time use)"
  sudo mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 "$DEVICE"
else
  log "$DEVICE already formatted; skipping mkfs"
fi

UUID="$(sudo blkid -s UUID -o value "$DEVICE")"
if [ -z "$UUID" ]; then
  log "failed to resolve UUID for $DEVICE"
  exit 1
fi

if ! grep -q "$UUID" /etc/fstab; then
  log "persisting mount in /etc/fstab"
  echo "UUID=$UUID $MOUNTPOINT ext4 noatime,nofail 0 2" | sudo tee -a /etc/fstab >/dev/null
else
  log "fstab already contains entry for UUID $UUID"
fi

log "mounting all entries"
sudo mount -a

log "setting owner to 999:999 and chmod 700"
sudo chown -R 999:999 "$MOUNTPOINT"
sudo chmod 700 "$MOUNTPOINT"

log "volume ready at $MOUNTPOINT (device $DEVICE, uuid $UUID)"
