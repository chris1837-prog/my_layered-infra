#!/bin/bash
set -xe

LOG_FILE="/var/log/elk-vm-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Starting ELK VM base setup..."

# --- Update system ---
apt-get update -y
apt-get upgrade -y

# --- Install dependencies ---
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release unzip

# --- Install Docker Engine ---
echo "[INFO] Installing Docker Engine..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# --- Enable and start Docker ---
systemctl enable docker
systemctl start docker

# --- Install Docker Compose plugin (v2) ---
echo "[INFO] Installing Docker Compose plugin (v2)..."
ARCH=$(uname -m)
DOCKER_CONFIG=${DOCKER_CONFIG:-/usr/lib/docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/v2.29.1/docker-compose-linux-$ARCH" -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

# --- Verify Docker installation ---
docker --version
docker compose version

# --- Install AWS SSM Agent (for remote troubleshooting) ---
echo "[INFO] Installing AWS SSM Agent..."
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# --- Cleanup ---
rm -f get-docker.sh

echo "[SUCCESS] ELK base VM setup complete! Docker and Compose are ready."

