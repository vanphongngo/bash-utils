#!/bin/bash

# New User Setup Script for Ubuntu 22.04 LTS
# For users created with: sudo useradd -m -u 0 -o -g root newadmin
# Usage: curl -s https://raw.githubusercontent.com/vanphongngo/bash-utils/setup-server/setup-user.sh | bash

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

# Check if user has root privileges
if [[ $EUID -ne 0 ]]; then
    error "This script requires root privileges. Please run as root or use sudo."
    exit 1
fi

# Get current user info
CURRENT_USER=$(whoami)
USER_HOME=$(eval echo ~$USER)

log "Starting new user setup for: $CURRENT_USER"
log "Home directory: $USER_HOME"

# Update package repositories if needed
log "Updating package repositories..."
apt update

# Install required packages
log "Installing required packages..."
apt install -y zsh git curl wget vim

# Setup SSH directory and authorized_keys
log "Setting up SSH directory and authorized_keys..."
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# Create .ssh directory if it doesn't exist
if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    log "Created SSH directory: $SSH_DIR"
fi

# Create authorized_keys file if it doesn't exist
if [ ! -f "$AUTHORIZED_KEYS" ]; then
    touch "$AUTHORIZED_KEYS"
    log "Created authorized_keys file: $AUTHORIZED_KEYS"
else
    log "authorized_keys file already exists"
fi

# Set proper permissions for SSH
chmod 700 "$SSH_DIR"
chmod 600 "$AUTHORIZED_KEYS"
chown -R $USER:root "$SSH_DIR"

info "SSH setup completed. Add your public key to: $AUTHORIZED_KEYS"
info "Example: echo 'your-public-key-here' >> $AUTHORIZED_KEYS"

# Install Oh My Zsh for the user
log "Installing Oh My Zsh..."
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    # Download and install Oh My Zsh non-interactively
    export RUNZSH=no
    export CHSH=no
    su - $USER -c 'sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
    log "Oh My Zsh installed successfully"
else
    warning "Oh My Zsh already installed"
fi

# Install Zsh plugins
log "Installing Zsh plugins..."
ZSH_CUSTOM="$USER_HOME/.oh-my-zsh/custom"

# Install zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    su - $USER -c "git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions"
    log "Installed zsh-autosuggestions"
fi

# Install zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    su - $USER -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    log "Installed zsh-syntax-highlighting"
fi

# Copy root's Zsh configuration if it exists and user wants it
ROOT_ZSHRC="/root/.zshrc"
USER_ZSHRC="$USER_HOME/.zshrc"

if [ -f "$ROOT_ZSHRC" ]; then
    log "Found root's .zshrc configuration"

    # Backup existing user .zshrc if it exists
    if [ -f "$USER_ZSHRC" ]; then
        cp "$USER_ZSHRC" "$USER_ZSHRC.backup.$(date +%Y%m%d_%H%M%S)"
        log "Backed up existing .zshrc"
    fi

    # Copy root's configuration
    cp "$ROOT_ZSHRC" "$USER_ZSHRC"
    log "Copied root's Zsh configuration to user"

    # Update the configuration for the new user
    sed -i "s|/root|$USER_HOME|g" "$USER_ZSHRC"

    # Ensure plugins are enabled (in case root config doesn't have them)
    if ! grep -q "zsh-autosuggestions" "$USER_ZSHRC"; then
        sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$USER_ZSHRC"
    fi

else
    log "No root .zshrc found, configuring default setup..."

    # Configure basic .zshrc with plugins
    if [ -f "$USER_ZSHRC" ]; then
        sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$USER_ZSHRC"
    fi
fi

# Add useful aliases to .zshrc
log "Adding useful aliases..."
cat >> "$USER_ZSHRC" << 'EOF'

# Custom aliases for new user
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Docker aliases (if Docker is installed)
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
alias sysinfo='dmidecode -t system'
alias ports='netstat -tulanp'
alias meminfo='free -m -l -t'
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'

# Admin aliases (since user has root privileges)
alias logs='journalctl -f'
alias services='systemctl list-units --type=service --state=running'
alias listening='ss -tuln'
alias diskspace='df -h'
alias memtop='top -o %MEM'
alias cputop='top -o %CPU'
EOF

# Set proper ownership for all user files
chown -R $USER:root "$USER_HOME/.oh-my-zsh" 2>/dev/null || true
chown $USER:root "$USER_ZSHRC" 2>/dev/null || true

# Change default shell to zsh for the user
log "Setting Zsh as default shell..."
chsh -s $(which zsh) $USER

# Setup NVM if it exists in root's profile
if [ -d "/root/.nvm" ] || command -v nvm &> /dev/null; then
    log "Setting up NVM for user..."

    # Add NVM configuration to user's .zshrc
    if ! grep -q "NVM_DIR" "$USER_ZSHRC"; then
        cat >> "$USER_ZSHRC" << 'EOF'

# NVM Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
    fi

    # Install NVM for the user
    su - $USER -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash'
    log "NVM installed for user"
fi

# Add user to docker group if Docker is installed
if command -v docker &> /dev/null; then
    log "Adding user to docker group..."
    usermod -aG docker $USER
    info "User added to docker group"
fi

# Create a simple SSH key adding function
log "Creating SSH key management script..."
cat > "$USER_HOME/add-ssh-key.sh" << 'EOF'
#!/bin/bash
# Quick script to add SSH public key

if [ $# -eq 0 ]; then
    echo "Usage: $0 'ssh-rsa AAAAB3... your-email@example.com'"
    echo "   or: $0 /path/to/public-key-file"
    exit 1
fi

AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"

if [ -f "$1" ]; then
    # If argument is a file, read from file
    cat "$1" >> "$AUTHORIZED_KEYS"
    echo "Added SSH key from file: $1"
else
    # If argument is the key itself
    echo "$1" >> "$AUTHORIZED_KEYS"
    echo "Added SSH key to authorized_keys"
fi

# Ensure proper permissions
chmod 600 "$AUTHORIZED_KEYS"
echo "SSH key added successfully!"
EOF

chmod +x "$USER_HOME/add-ssh-key.sh"
chown $USER:root "$USER_HOME/add-ssh-key.sh"

info "Created SSH key management script: $USER_HOME/add-ssh-key.sh"

# Display setup summary
log "User setup completed successfully!"
echo "=========================="
info "✓ SSH directory and authorized_keys created"
info "✓ SSH permissions configured (700/600)"
info "✓ Oh My Zsh installed with plugins"
info "✓ Zsh autosuggestions and syntax highlighting enabled"
info "✓ Root's Zsh configuration copied (if available)"
info "✓ Useful aliases added"
info "✓ Zsh set as default shell"
info "✓ User added to docker group (if Docker installed)"
info "✓ SSH key management script created"
echo "=========================="

warning "Please log out and log back in for shell changes to take effect"

echo ""
info "Next steps:"
echo "1. Add your SSH public key:"
echo "   $USER_HOME/add-ssh-key.sh 'your-ssh-public-key'"
echo "   OR manually edit: $AUTHORIZED_KEYS"
echo ""
echo "2. Test SSH key authentication:"
echo "   ssh $USER@your-server-ip"
echo ""
echo "3. Start using Zsh:"
echo "   exec zsh"

info "SSH authorized_keys location: $AUTHORIZED_KEYS"
info "Add SSH Key script: $USER_HOME/add-ssh-key.sh"

# Display current user info
echo ""
info "User Information:"
echo "Username: $CURRENT_USER"
echo "Home Directory: $USER_HOME"
echo "Shell: $(getent passwd $USER | cut -d: -f7)"
echo "Groups: $(groups $USER)"
echo "SSH Directory: $SSH_DIR"