#!/bin/bash

# Script to install Docker and Docker Compose on CentOS 8

# --- Variables ---
DOCKER_COMPOSE_VERSION="v2.27.0" # Check for the latest version at: https://github.com/docker/compose/releases

# --- Helper Functions for Logging ---
loginfo() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

logwarn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

logerror() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# --- Check for root privileges ---
if [ "$(id -u)" -ne 0 ]; then
    logerror "This script must be run as root (or with sudo)."
    exit 1
fi

# --- Warning about CentOS 8 EOL ---
logwarn "NOTE: CentOS 8 has reached End Of Life (EOL)."
logwarn "You should consider migrating to a supported OS like AlmaLinux 8, Rocky Linux 8, or CentOS Stream."
read -p "Do you want to continue with the installation on CentOS 8? (y/N): " confirm_centos8
if [[ "$confirm_centos8" != [yY] ]]; then
    loginfo "Installation aborted."
    exit 0
fi

# --- Update system and configure repositories (if needed for CentOS 8 EOL) ---
loginfo "Updating system..."
dnf update -y
if [ $? -ne 0 ]; then
    logwarn "System update failed. This might be due to CentOS 8 EOL repositories."
    logwarn "Attempting to switch to vault.centos.org..."
    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
    dnf clean all
    dnf update -y
    if [ $? -ne 0 ]; then
        logerror "Still unable to update the system. Please check your repository configuration manually."
        exit 1
    fi
fi

# --- Uninstall old Docker versions (if any) ---
loginfo "Uninstalling old Docker versions (if any)..."
dnf remove -y docker \
              docker-client \
              docker-client-latest \
              docker-common \
              docker-latest \
              docker-latest-logrotate \
              docker-logrotate \
              docker-selinux \
              docker-engine-selinux \
              docker-engine \
              podman \
              runc
# Remove leftover directories (be cautious if you have old Docker data you want to keep)
# rm -rf /var/lib/docker
# rm -rf /var/lib/containerd

# --- Install necessary dependencies ---
loginfo "Installing dependencies..."
dnf install -y dnf-utils device-mapper-persistent-data lvm2 curl

# --- Add Docker CE repository ---
loginfo "Adding Docker CE repository..."
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
if [ $? -ne 0 ]; then
    logerror "Failed to add Docker CE repository. Check network connection or repository URL."
    exit 1
fi

# --- Install Docker Engine ---
loginfo "Installing Docker Engine..."
# Attempt to install the latest version. If it fails, you might need a more specific version.
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
if [ $? -ne 0 ]; then
    logwarn "Installation of the latest Docker CE version failed."
    # You might need to find a compatible version for CentOS 8 here:
    # dnf list docker-ce --showduplicates | sort -r
    # Example: dnf install -y docker-ce-3:20.10.9-3.el8 docker-ce-cli-1:20.10.9-3.el8 containerd.io
    logerror "Failed to install Docker Engine. Please check the errors and try manual installation."
    exit 1 # Script will now exit if Docker Engine installation fails
fi

# --- Start and enable Docker service ---
loginfo "Starting and enabling Docker service..."
systemctl start docker
if [ $? -ne 0 ]; then
    logerror "Failed to start Docker service."
    systemctl status docker
    exit 1
fi
systemctl enable docker
if [ $? -ne 0 ]; then
    logwarn "Failed to enable Docker service to start on boot."
fi

loginfo "Docker has been installed and started."
docker --version

# --- Install Docker Compose (standalone version) ---
# Docker Compose v2 is now integrated as a plugin (docker-compose-plugin)
# However, if you want the standalone version or the plugin isn't working, you can install it manually.

read -p "Docker Compose v2 is typically installed as a plugin ('docker compose'). Do you want to install the standalone Docker Compose ('docker-compose') as well? (y/N): " install_standalone_compose
if [[ "$install_standalone_compose" == [yY] ]]; then
    loginfo "Installing Docker Compose version ${DOCKER_COMPOSE_VERSION}..."
    curl -SL https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
    if [ $? -ne 0 ]; then
        logerror "Failed to download Docker Compose. Check network connection or URL."
        exit 1
    fi

    chmod +x /usr/local/bin/docker-compose
    if [ $? -ne 0 ]; then
        logerror "Failed to set execute permission for Docker Compose."
        exit 1
    fi

    # Create a symbolic link to /usr/bin (optional, some scripts might look for it here)
    # ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    loginfo "Docker Compose (standalone) has been installed."
    docker-compose --version
else
    loginfo "Skipping standalone Docker Compose installation. You can use 'docker compose' (if the plugin was installed)."
    if command -v docker-compose-plugin &> /dev/null || docker compose version &> /dev/null; then
        loginfo "The Docker Compose plugin ('docker compose') seems to be installed."
        docker compose version
    else
        logwarn "The Docker Compose plugin ('docker compose') does not seem to be installed or working."
        logwarn "You might need to install 'docker-compose-plugin' or re-run the script and choose to install the standalone version."
    fi
fi


# --- (Optional) Add current user to the docker group to run docker commands without sudo ---
CURRENT_USER=$(logname 2>/dev/null || echo "$SUDO_USER")
if [ -n "$CURRENT_USER" ] && [ "$CURRENT_USER" != "root" ]; then
    read -p "Do you want to add user '$CURRENT_USER' to the 'docker' group to run docker commands without sudo? (y/N): " add_user_to_group
    if [[ "$add_user_to_group" == [yY] ]]; then
        usermod -aG docker "$CURRENT_USER"
        loginfo "User '$CURRENT_USER' has been added to the 'docker' group."
        loginfo "You need to log out and log back in for this change to take effect."
    fi
else
    loginfo "No non-root user found to add to the docker group, or currently running as root."
fi

loginfo "Installation complete!"
loginfo "To test Docker, you can run: sudo docker run hello-world"
loginfo "If you added your user to the docker group, log out and log back in before trying 'docker run hello-world' without sudo."

exit 0
