# Ubuntu 22.04 LTS Server Setup Script

Automated server setup script for Ubuntu 22.04 LTS that installs and configures essential development and server tools in one command.

## Quick Start

```bash
curl -s https://raw.githubusercontent.com/vanphongngo/bash-utils/setup-server/setup.sh | bash
```

## Requirements

- **OS**: Ubuntu 22.04 LTS (tested and optimized)
- **User**: Non-root user with sudo privileges
- **Internet**: Active internet connection
- **Storage**: At least 2GB free space

## What Gets Installed

### Shell Enhancement
- **Zsh** - Modern shell with enhanced features
- **Oh My Zsh** - Framework for managing Zsh configuration
- **Zsh Autosuggestions** - Fish-like autosuggestions for Zsh
- **Zsh Syntax Highlighting** - Real-time syntax highlighting

### Development Tools
- **Node.js LTS** - Latest Long Term Support version via NVM
- **NVM** - Node Version Manager for managing Node.js versions
- **Git** - Version control system
- **Essential packages**: curl, wget, vim, htop, unzip

### Server Components
- **Nginx** - High-performance web server
- **Docker Engine** - Container platform
- **Docker Compose** - Multi-container application management
- **UFW Firewall** - Configured for web traffic and SSH

### Security
- **SSH Key Generation** - RSA 4096-bit key pair
- **Firewall Configuration** - UFW enabled with Nginx and SSH rules
- **User Permissions** - Docker group membership for non-root usage

## Installation Process

The script performs the following steps:

1. **System Preparation**
   - Updates package repositories
   - Upgrades existing packages
   - Installs essential dependencies

2. **Shell Setup**
   - Installs Zsh and Oh My Zsh
   - Configures autosuggestions and syntax highlighting
   - Sets Zsh as default shell
   - Backs up existing `.zshrc` if present

3. **Security Setup**
   - Generates SSH key pair (if not exists)
   - Displays public key for easy copying
   - Configures UFW firewall

4. **Development Environment**
   - Installs NVM (Node Version Manager)
   - Installs latest Node.js LTS
   - Configures NVM in shell profile

5. **Server Components**
   - Installs and starts Nginx
   - Installs Docker Engine and Compose
   - Adds user to docker group
   - Starts and enables services

6. **Configuration & Aliases**
   - Adds useful command aliases
   - Configures shell environment
   - Performs system cleanup

## Post-Installation

### Required Action
After installation completes, you must:

```bash
# Either log out and log back in, OR run:
newgrp docker && exec zsh
```

This activates:
- Docker group membership
- Zsh as default shell
- All environment configurations

### Verify Installation

Check installed versions:
```bash
zsh --version
node --version
npm --version
nginx -v
docker --version
docker-compose --version
```

Test services:
```bash
# Test Nginx
curl localhost

# Test Docker
docker run hello-world

# Test Node.js
node -e "console.log('Node.js is working!')"
```

## Available Aliases

The script adds useful aliases to your `.zshrc`:

### File Operations
```bash
ll      # ls -alF (detailed list)
la      # ls -A (show hidden files)
l       # ls -CF (compact list)
..      # cd .. (go up one directory)
...     # cd ../.. (go up two directories)
```

### Docker Shortcuts
```bash
d       # docker
dc      # docker-compose
dps     # docker ps (running containers)
di      # docker images
drmi    # docker rmi (remove image)
dstop   # Stop all containers
drm     # Remove all containers
```

### Git Shortcuts
```bash
g       # git
gs      # git status
ga      # git add
gc      # git commit
gp      # git push
gl      # git pull
gco     # git checkout
gb      # git branch
```

### System Information
```bash
sysinfo # System hardware info
ports   # Show network ports
meminfo # Memory usage info
psmem   # Processes by memory usage
pscpu   # Processes by CPU usage
```

## SSH Key Setup

The script generates an SSH key at `~/.ssh/id_rsa` if one doesn't exist. To use it:

1. **Display your public key:**
   ```bash
   cat ~/.ssh/id_rsa.pub
   ```

2. **Add to GitHub/GitLab:**
   - Copy the entire public key output
   - Go to your Git provider's SSH key settings
   - Add the key with a descriptive name

3. **Test SSH connection:**
   ```bash
   # For GitHub
   ssh -T git@github.com

   # For GitLab
   ssh -T git@gitlab.com
   ```

## Docker Usage

After installation, Docker is ready to use:

```bash
# Run a container
docker run -d --name nginx-test -p 8080:80 nginx

# Check running containers
dps

# View logs
docker logs nginx-test

# Stop and remove
docker stop nginx-test
docker rm nginx-test
```

## Nginx Configuration

Nginx is installed and running on port 80:

- **Config location**: `/etc/nginx/`
- **Default root**: `/var/www/html/`
- **Service control**: `sudo systemctl {start|stop|restart|status} nginx`

Test the installation:
```bash
curl localhost
# Should return the default Nginx welcome page
```

## Node.js Development

NVM allows you to manage multiple Node.js versions:

```bash
# List available versions
nvm list-remote

# Install specific version
nvm install 18.17.0

# Switch versions
nvm use 18.17.0

# Set default version
nvm alias default 18.17.0

# Install global packages
npm install -g pm2 nodemon
```

## Firewall Configuration

UFW (Uncomplicated Firewall) is configured with these rules:

```bash
# Check status
sudo ufw status

# Allowed services:
# - SSH (port 22)
# - Nginx Full (ports 80, 443)
```

Add custom rules:
```bash
# Allow specific port
sudo ufw allow 3000

# Allow from specific IP
sudo ufw allow from 192.168.1.100

# Allow specific service
sudo ufw allow 'OpenSSH'
```

## Troubleshooting

### Common Issues

**1. Permission denied for Docker:**
```bash
# Ensure you're in docker group
groups
# Should show 'docker' in the list

# If not, run:
sudo usermod -aG docker $USER
newgrp docker
```

**2. Node/NPM command not found:**
```bash
# Reload shell configuration
source ~/.zshrc

# Or restart terminal session
exec zsh
```

**3. Zsh not default shell:**
```bash
# Check current shell
echo $SHELL

# Change to zsh
chsh -s $(which zsh)
# Logout and login again
```

**4. Nginx not accessible:**
```bash
# Check service status
sudo systemctl status nginx

# Check firewall
sudo ufw status

# Check if port 80 is in use
sudo netstat -tlnp | grep :80
```

### Log Locations

- **Nginx**: `/var/log/nginx/`
- **Docker**: `journalctl -u docker`
- **System**: `/var/log/syslog`

### Uninstall Components

If you need to remove installed components:

```bash
# Remove Docker
sudo apt remove docker-ce docker-ce-cli containerd.io
sudo rm -rf /var/lib/docker

# Remove Node.js/NVM
rm -rf ~/.nvm
# Remove NVM lines from ~/.zshrc

# Remove Nginx
sudo apt remove nginx nginx-common
sudo rm -rf /etc/nginx

# Restore bash as default shell
chsh -s /bin/bash
```

## Script Safety Features

- **Root check**: Prevents running as root user
- **Backup**: Creates timestamped backup of existing `.zshrc`
- **Error handling**: Stops on any command failure (`set -e`)
- **Idempotent**: Safe to run multiple times
- **Version check**: Warns if not Ubuntu 22.04

## Customization

You can modify the script before running:

1. **Download the script:**
   ```bash
   wget https://raw.githubusercontent.com/vanphongngo/bash-utils/setup-server/setup.sh
   ```

2. **Edit as needed:**
   ```bash
   vim setup.sh
   ```

3. **Run locally:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

## Support

For issues or questions:
- Check the troubleshooting section above
- Review installation logs for error messages
- Ensure all requirements are met
- Verify internet connectivity during installation

## License

This script is provided as-is for educational and development purposes.