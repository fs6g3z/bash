#!/bin/bash

set -e
set -u
set -o pipefail

log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
    exit 1
}

log_info "Starting Docker and Docker Compose installation on Ubuntu 22.04..."

if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root or with sudo."
fi

log_info "Removing old Docker versions (if any)..."
apt-get remove -y docker docker-engine docker.io containerd runc > /dev/null 2>&1 || true
apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras > /dev/null 2>&1 || true
rm -rf /var/lib/docker
rm -rf /var/lib/containerd
log_info "Old Docker versions removed."

log_info "Updating package list and installing prerequisites..."
apt-get update -y
apt-get install -y \
    ca-certificates \
    curl \
    gnupg

log_info "Adding Docker's official GPG key..."
install -m 0755 -d /etc/apt/keyrings
if [ -f /etc/apt/keyrings/docker.gpg ]; then
    rm -f /etc/apt/keyrings/docker.gpg
fi
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

log_info "Setting up Docker repository..."
UBUNTU_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  ${UBUNTU_CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

log_info "Installing Docker Engine, CLI, Containerd, and Docker Compose plugin..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

log_info "Verifying Docker installation..."
if ! command -v docker &> /dev/null; then
    log_error "Docker command could not be found after installation."
fi
DOCKER_VERSION=$(docker --version)
log_info "Docker version: $DOCKER_VERSION"

log_info "Verifying Docker Compose (plugin) installation..."
if ! docker compose version &> /dev/null; then
    log_error "Docker Compose (plugin) command could not be found after installation."
fi
COMPOSE_VERSION=$(docker compose version)
log_info "Docker Compose version: $COMPOSE_VERSION"

CALLING_USER="${SUDO_USER:-$USER}"

if [ -n "$CALLING_USER" ] && [ "$CALLING_USER" != "root" ]; then
    log_info "Adding user '$CALLING_USER' to the 'docker' group..."
    if ! getent group docker > /dev/null; then
        log_info "Docker group does not exist. Creating it."
        groupadd docker
    fi
    usermod -aG docker "$CALLING_USER"
    log_info "User '$CALLING_USER' added to the 'docker' group."
    log_warn "You need to log out and log back in for the group changes to take effect for user '$CALLING_USER',"
    log_warn "or run 'newgrp docker' in a new shell session."
else
    log_info "Skipping adding user to 'docker' group (current user is root or SUDO_USER not set)."
fi

log_info "Ensuring Docker service is enabled and started..."
systemctl enable docker.service > /dev/null 2>&1
systemctl enable containerd.service > /dev/null 2>&1
systemctl start docker.service
systemctl start containerd.service

log_info "Running hello-world container to test Docker..."
if docker run hello-world; then
    log_info "Docker is working correctly! The hello-world container ran successfully."
else
    log_error "Failed to run hello-world container. Docker installation might have issues."
fi

log_info "--------------------------------------------------------------------"
log_info "Docker and Docker Compose (plugin) installation completed successfully!"
log_info "Docker Version: $DOCKER_VERSION"
log_info "Docker Compose Version: $COMPOSE_VERSION"
if [ -n "$CALLING_USER" ] && [ "$CALLING_USER" != "root" ]; then
  log_warn "REMEMBER: Log out and log back in for user '$CALLING_USER' to run 'docker' commands without sudo."
fi
log_info "--------------------------------------------------------------------"

exit 0
