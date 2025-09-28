#!/bin/bash

# Ubuntu 22.04 LTS Server Setup Script
# Usage: curl -s https://raw.githubusercontent.com/vanphongngo/bash-utils/setup-server/setup.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root"
    exit 1
fi

# Check Ubuntu version
if ! grep -q "22.04" /etc/os-release; then
    warning "This script is designed for Ubuntu 22.04 LTS. Proceeding anyway..."
fi

log "Starting Ubuntu 22.04 LTS Server Setup..."

# Update system packages
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
log "Installing essential packages..."
sudo apt install -y curl wget git vim htop unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release

# Install Zsh
log "Installing Zsh..."
sudo apt install -y zsh

# Install Oh My Zsh
log "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install Zsh autosuggestions
log "Installing Zsh autosuggestions..."
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
fi

# Install Zsh syntax highlighting
log "Installing Zsh syntax highlighting..."
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
fi

# Configure Zsh
log "Configuring Zsh..."
if [ -f "$HOME/.zshrc" ]; then
    # Backup existing .zshrc
    cp $HOME/.zshrc $HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
fi

# Update .zshrc with plugins
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' $HOME/.zshrc

# Change default shell to zsh
log "Changing default shell to Zsh..."
sudo chsh -s $(which zsh) $USER

# Generate SSH key
log "Generating SSH key..."
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    ssh-keygen -t rsa -b 4096 -C "$(whoami)@$(hostname)" -f $HOME/.ssh/id_rsa -N ""
    log "SSH key generated at $HOME/.ssh/id_rsa"
    info "Your public key:"
    cat $HOME/.ssh/id_rsa.pub
else
    warning "SSH key already exists at $HOME/.ssh/id_rsa"
fi

# Install NVM (Node Version Manager)
log "Installing NVM..."
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

    # Load NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    # Add NVM to .zshrc
    echo 'export NVM_DIR="$HOME/.nvm"' >> $HOME/.zshrc
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> $HOME/.zshrc
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> $HOME/.zshrc
else
    warning "NVM already installed"
fi

# Install Node.js LTS
log "Installing Node.js LTS..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
nvm alias default lts/*

# Install Nginx
log "Installing Nginx..."
sudo apt install -y nginx

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Configure firewall for Nginx
log "Configuring firewall for Nginx..."
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH
sudo ufw --force enable

# Install Docker dependencies
log "Installing Docker dependencies..."
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
log "Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
log "Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
sudo apt update

# Install Docker Engine
log "Installing Docker Engine..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
log "Adding user to docker group..."
sudo usermod -aG docker $USER

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Install Docker Compose (standalone)
log "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create useful aliases
log "Creating useful aliases..."
cat >> $HOME/.zshrc << 'EOF'

# Custom aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'
alias drmi='docker rmi'
alias dstop='docker stop $(docker ps -aq)'
alias drm='docker rm $(docker ps -aq)'

# Git aliases
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gco='git checkout'
alias gb='git branch'

# System aliases
alias sysinfo='sudo dmidecode -t system'
alias ports='netstat -tulanp'
alias meminfo='free -m -l -t'
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'
EOF

# Final system cleanup
log "Performing system cleanup..."
sudo apt autoremove -y
sudo apt autoclean

# Display installation summary
log "Installation Summary:"
echo "=========================="
info " Zsh with Oh My Zsh installed"
info " Zsh autosuggestions and syntax highlighting enabled"
info " SSH key generated (if not existed)"
info " NVM and Node.js LTS installed"
info " Nginx installed and configured"
info " Docker and Docker Compose installed"
info " Firewall configured (UFW enabled)"
info " User added to docker group"
info " Useful aliases added to .zshrc"
echo "=========================="

warning "Please log out and log back in for all changes to take effect"
warning "OR run: newgrp docker && exec zsh"

log "Server setup completed successfully!"

# Display versions
echo ""
info "Installed versions:"
echo "Zsh: $(zsh --version)"
echo "Node.js: $(node --version 2>/dev/null || echo 'Restart session to use nvm')"
echo "NPM: $(npm --version 2>/dev/null || echo 'Restart session to use nvm')"
echo "Nginx: $(nginx -v 2>&1)"
echo "Docker: $(docker --version)"
echo "Docker Compose: $(docker-compose --version)"

info "Your SSH public key (add to GitHub/GitLab):"
if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    cat $HOME/.ssh/id_rsa.pub
fi