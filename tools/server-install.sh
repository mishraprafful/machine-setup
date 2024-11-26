#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Starting installation process for Fail2Ban, RKHunter, NVIDIA drivers, CUDA, NVIDIA CUDA Toolkit, Docker (rootless), and NVIDIA container toolkit..."

# Function to install Fail2Ban and RKHunter
install_security_tools() {
    echo "Installing Fail2Ban and RKHunter for system security..."

    # Update package index and install Fail2Ban and RKHunter
    sudo apt-get update
    sudo apt-get install -y fail2ban rkhunter

    # Configure and update RKHunter
    echo "Updating RKHunter database..."
    sudo rkhunter --update
    sudo rkhunter --propupd

    # Enable and start Fail2Ban service
    echo "Enabling and starting Fail2Ban..."
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban

    echo "Fail2Ban and RKHunter installation and configuration complete."
}

# Function to check and install NVIDIA drivers using ubuntu-drivers
install_nvidia_drivers_and_toolkit() {
    echo "Installing NVIDIA drivers, CUDA, and NVIDIA CUDA Toolkit..."
    
    # Update the package index and install ubuntu-drivers utility
    sudo apt-get update
    sudo apt-get install -y ubuntu-drivers-common

    # Automatically install the recommended NVIDIA driver
    echo "Detecting and installing the recommended NVIDIA driver..."
    sudo ubuntu-drivers autoinstall

    # Install CUDA and NVIDIA CUDA Toolkit
    sudo apt-get update
    sudo apt-get install -y cuda nvidia-cuda-toolkit

    echo "NVIDIA drivers, CUDA, and NVIDIA CUDA Toolkit installation complete. Reboot required for changes to take effect."
}

# Function to install Docker in rootless mode
install_docker_rootless() {
    echo "Installing Docker in rootless mode..."

    # Install required packages
    sudo apt-get update
    sudo apt-get install -y curl slirp4netns uidmap dbus-user-session docker-ce-rootless-extras
    
    # Install Docker using the official script
    curl -fsSL https://get.docker.com/rootless | sh

    # Set up Docker for rootless
    export PATH=/usr/bin:$PATH
    dockerd-rootless-setuptool.sh install

    # Configure environment variables
    echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
    echo 'export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock' >> ~/.bashrc
    source ~/.bashrc

    echo "Docker rootless installation complete."
}

# Function to create the docker group and add the current user
setup_docker_group() {
    echo "Setting up docker group to allow non-root Docker usage..."

    # Create the docker group if it doesn't exist
    if ! getent group docker > /dev/null 2>&1; then
        echo "Creating docker group..."
        sudo groupadd docker
    else
        echo "Docker group already exists."
    fi

    # Add the current user to the docker group
    echo "Adding current user $(whoami) to the docker group..."
    sudo usermod -aG docker $(whoami)

    # Inform the user to log out and log back in for changes to take effect
    echo "You need to log out and log back in to apply the new group membership."
}

# Function to install NVIDIA Container Toolkit
install_nvidia_container_toolkit() {
    echo "Installing NVIDIA Container Toolkit..."

    # Add NVIDIA Container Toolkit repository
    distribution=$(. /etc/os-release; echo $ID$VERSION_ID) \
        && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
        && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    # Install the toolkit
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit

    # Configure the NVIDIA Container Toolkit for rootless Docker
    sudo nvidia-ctk runtime configure --runtime=docker

    # Reload Docker daemon (rootless)
    sudo systemctl --user restart docker || echo "Please log out and log back in to apply rootless Docker changes."

    echo "NVIDIA Container Toolkit installation and configuration complete."
}

# Run the installation steps
install_security_tools
install_nvidia_drivers_and_toolkit
install_docker_rootless
install_nvidia_container_toolkit

# Verify the installation
echo "Verifying security tools installation..."
if ! systemctl is-active --quiet fail2ban; then
    echo "Fail2Ban service is not active. Check its configuration."
    exit 1
fi
if ! rkhunter --version; then
    echo "RKHunter installation failed. Check your system and retry."
    exit 1
fi

echo "Verifying NVIDIA driver installation..."
if ! nvidia-smi; then
    echo "NVIDIA driver installation failed. Check your system and retry."
    exit 1
fi

echo "Verifying CUDA Toolkit installation..."
if ! nvcc --version; then
    echo "CUDA Toolkit installation failed. Check your system and retry."
    exit 1
fi

echo "Verifying Docker rootless installation..."
if ! docker info | grep "Rootless"; then
    echo "Docker rootless setup failed. Check the logs for issues."
    exit 1
fi

echo "Verifying NVIDIA Container Toolkit configuration..."
if ! docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi | grep -q "Driver Version"; then
    echo "NVIDIA Container Toolkit setup failed. GPU not detected in the container."
    exit 1
fi

echo "Installation complete! Reboot your system for all changes to take effect."
