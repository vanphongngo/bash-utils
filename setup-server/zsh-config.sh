#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  ZSH AUTO SETUP SCRIPT${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            OS="debian"
        elif [ -f /etc/redhat-release ]; then
            OS="redhat"
        elif [ -f /etc/arch-release ]; then
            OS="arch"
        else
            OS="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        OS="unknown"
    fi
}

# Install zsh based on OS
install_zsh() {
    print_status "Installing zsh..."

    case $OS in
        "debian")
            sudo apt update
            sudo apt install -y zsh git curl
            ;;
        "redhat")
            if command -v dnf &> /dev/null; then
                sudo dnf install -y zsh git curl
            else
                sudo yum install -y zsh git curl
            fi
            ;;
        "arch")
            sudo pacman -S --noconfirm zsh git curl
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install zsh git curl
            else
                print_error "Homebrew not found. Please install Homebrew first."
                exit 1
            fi
            ;;
        *)
            print_error "Unsupported operating system: $OSTYPE"
            exit 1
            ;;
    esac
}

# Install Oh My Zsh
install_oh_my_zsh() {
    print_status "Installing Oh My Zsh..."

    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_warning "Oh My Zsh is already installed"
    else
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
}

# Install zsh-autosuggestions
install_autosuggestions() {
    print_status "Installing zsh-autosuggestions..."

    ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

    if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        print_warning "zsh-autosuggestions is already installed"
    else
        git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
    fi
}

# Install zsh-syntax-highlighting
install_syntax_highlighting() {
    print_status "Installing zsh-syntax-highlighting..."

    ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

    if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        print_warning "zsh-syntax-highlighting is already installed"
    else
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
    fi
}

# Install Powerlevel10k theme (optional)
install_powerlevel10k() {
    print_status "Installing Powerlevel10k theme..."

    ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

    if [ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
        print_warning "Powerlevel10k is already installed"
    else
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k
    fi
}

# Configure .zshrc
configure_zshrc() {
    print_status "Configuring .zshrc..."

    # Backup existing .zshrc if it exists
    if [ -f "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backed up existing .zshrc"
    fi

    # Create new .zshrc
    cat > "$HOME/.zshrc" << 'EOF'
# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    docker
    docker-compose
    npm
    node
    python
    pip
    kubectl
    helm
)

# Oh My Zsh
source $ZSH/oh-my-zsh.sh

# User configuration
export LANG=en_US.UTF-8
export EDITOR='nano'

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Docker aliases
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs'
alias dcp='docker-compose'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'
alias glog='git log --oneline --graph --decorate'

# System aliases
alias update-system='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install'
alias search='apt search'
alias h='history'
alias c='clear'
alias x='exit'

# Network aliases
alias myip='curl -s https://ipinfo.io/ip'
alias ports='netstat -tuln'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

    print_status ".zshrc configured successfully"
}

# Change default shell to zsh
change_shell() {
    print_status "Changing default shell to zsh..."

    # Get zsh path
    ZSH_PATH=$(which zsh)

    if [ -z "$ZSH_PATH" ]; then
        print_error "zsh not found in PATH"
        exit 1
    fi

    # Add zsh to /etc/shells if not present
    if ! grep -q "$ZSH_PATH" /etc/shells; then
        print_status "Adding zsh to /etc/shells..."
        echo "$ZSH_PATH" | sudo tee -a /etc/shells
    fi

    # Change shell for current user
    if [ "$SHELL" != "$ZSH_PATH" ]; then
        print_status "Changing shell to zsh (you may need to enter your password)..."
        chsh -s "$ZSH_PATH"
        print_status "Shell changed to zsh. Please log out and log back in for changes to take effect."
    else
        print_status "Shell is already set to zsh"
    fi
}

# Final setup message
show_completion_message() {
    print_header
    echo -e "${GREEN}✅ ZSH setup completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}What was installed:${NC}"
    echo "  • Zsh shell"
    echo "  • Oh My Zsh framework"
    echo "  • zsh-autosuggestions plugin"
    echo "  • zsh-syntax-highlighting plugin"
    echo "  • Powerlevel10k theme"
    echo "  • Useful aliases and configurations"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Log out and log back in (or restart your terminal)"
    echo "  2. Run 'p10k configure' to customize your prompt"
    echo "  3. Enjoy your enhanced zsh experience!"
    echo ""
    echo -e "${BLUE}Useful commands:${NC}"
    echo "  • 'p10k configure' - Configure Powerlevel10k theme"
    echo "  • 'omz update' - Update Oh My Zsh"
    echo "  • 'omz plugin list' - List available plugins"
    echo ""
}

# Main execution
main() {
    print_header

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root"
        exit 1
    fi

    # Detect OS
    detect_os
    print_status "Detected OS: $OS"

    # Check if zsh is already installed
    if command -v zsh &> /dev/null; then
        print_warning "zsh is already installed"
    else
        install_zsh
    fi

    # Install components
    install_oh_my_zsh
    install_autosuggestions
    install_syntax_highlighting
    install_powerlevel10k

    # Configure
    configure_zshrc
    change_shell

    # Show completion message
    show_completion_message
}

# Run main function
main "$@"