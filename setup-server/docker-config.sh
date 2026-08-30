#!/usr/bin/env bash
# docker-config.sh — Install Docker Engine + Compose plugin on Ubuntu.
# Safe to run non-interactively:  curl -fsSL <raw-url> | bash

set -euo pipefail

# 1. Update your system
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# 2. Install required dependencies
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 3. Add Docker's official GPG key
#    --yes lets a re-run overwrite the existing key instead of aborting,
#    and the keyring must be world-readable or apt cannot verify the repo.
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 4. Set up the stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Update package index with Docker repo
sudo apt-get update

# 6. Install Docker Engine, CLI, containerd
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 7. Start & enable Docker service
sudo systemctl enable docker
sudo systemctl start docker

# 8. Allow the current user to run docker without sudo.
#    Takes effect on the next login (or run: newgrp docker).
sudo usermod -aG docker "$USER"

# 9. Verify
sudo docker version
sudo docker compose version
echo "✅ Docker installed. Log out and back in for the 'docker' group to apply."
