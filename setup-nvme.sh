#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup-nvme.sh
#
# Run this on the Jetson to set up the NVMe drive for Docker and homelab data.
# WARNING: This will WIPE the NVMe drive!
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/TonsOfFun/jetson-homelab/main/setup-nvme.sh | bash
#   # OR
#   ./setup-nvme.sh
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[nvme-setup]${NC} $*"; }
warn()  { echo -e "${YELLOW}[nvme-setup]${NC} $*"; }
error() { echo -e "${RED}[nvme-setup]${NC} $*"; }

NVME_DEVICE="/dev/nvme0n1"
NVME_PART="${NVME_DEVICE}p1"
MOUNT_POINT="/mnt/nvme"
LABEL="nvme-data"

# ── Preflight checks ─────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  error "This script must be run as root (use sudo)"
  exit 1
fi

if [ ! -b "$NVME_DEVICE" ]; then
  error "NVMe device $NVME_DEVICE not found"
  exit 1
fi

# ── Confirmation ─────────────────────────────────────────────────────────────
echo ""
warn "WARNING: This will ERASE ALL DATA on $NVME_DEVICE"
lsblk "$NVME_DEVICE"
echo ""
read -rp "Type 'yes' to continue: " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

# ── Wipe and partition ───────────────────────────────────────────────────────
info "Wiping $NVME_DEVICE..."
wipefs -a "$NVME_DEVICE"

info "Creating GPT partition table..."
parted -s "$NVME_DEVICE" mklabel gpt

info "Creating partition..."
parted -s "$NVME_DEVICE" mkpart primary ext4 0% 100%

# Wait for partition to appear
sleep 2

info "Formatting as ext4 with label '$LABEL'..."
mkfs.ext4 -L "$LABEL" "$NVME_PART"

# ── Mount ────────────────────────────────────────────────────────────────────
info "Creating mount point at $MOUNT_POINT..."
mkdir -p "$MOUNT_POINT"

info "Mounting $NVME_PART to $MOUNT_POINT..."
mount "$NVME_PART" "$MOUNT_POINT"

# ── Move Docker data ─────────────────────────────────────────────────────────
info "Stopping Docker..."
systemctl stop docker docker.socket containerd || true

if [ -d /var/lib/docker ] && [ ! -L /var/lib/docker ]; then
  info "Moving /var/lib/docker to NVMe..."
  mv /var/lib/docker "$MOUNT_POINT/"
  ln -s "$MOUNT_POINT/docker" /var/lib/docker
  info "Created symlink /var/lib/docker -> $MOUNT_POINT/docker"
else
  warn "/var/lib/docker is already a symlink or doesn't exist, skipping"
fi

# ── Move homelab data ────────────────────────────────────────────────────────
if [ -d /opt/homelab ] && [ ! -L /opt/homelab ]; then
  info "Moving /opt/homelab to NVMe..."
  mv /opt/homelab "$MOUNT_POINT/"
  ln -s "$MOUNT_POINT/homelab" /opt/homelab
  info "Created symlink /opt/homelab -> $MOUNT_POINT/homelab"
elif [ ! -e /opt/homelab ]; then
  info "Creating /opt/homelab on NVMe..."
  mkdir -p "$MOUNT_POINT/homelab"
  ln -s "$MOUNT_POINT/homelab" /opt/homelab
fi

# ── Add to fstab ─────────────────────────────────────────────────────────────
if ! grep -q "$LABEL" /etc/fstab; then
  info "Adding NVMe to /etc/fstab for persistence..."
  echo "LABEL=$LABEL $MOUNT_POINT ext4 defaults,noatime 0 2" >> /etc/fstab
else
  warn "NVMe already in /etc/fstab, skipping"
fi

# ── Restart Docker ───────────────────────────────────────────────────────────
info "Starting Docker..."
systemctl start docker

# ── Verify ───────────────────────────────────────────────────────────────────
echo ""
info "NVMe setup complete!"
echo ""
df -h "$MOUNT_POINT"
echo ""
info "Docker images:"
docker images
echo ""
info "Next: run 'make provision-homelab' from your Mac to start the containers"
