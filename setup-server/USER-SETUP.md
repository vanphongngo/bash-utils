# New User Setup Script

Automated setup script for new users created with root privileges on Ubuntu 22.04 LTS servers.

## Prerequisites

1. **Server with main setup completed** using the main `setup.sh` script
2. **New user created** with root privileges:
   ```bash
   sudo useradd -m -u 0 -o -g root admin
   sudo passwd admin
   ```
3. **Logged in as the new user** before running this script

## Quick Start

```bash
# After logging in as the new user (e.g., newadmin)

su - admin

curl -s https://raw.githubusercontent.com/vanphongngo/bash-utils/master/setup-server/setup-user.sh | bash
```

## What This Script Does

### SSH Key Setup
- ✅ Creates `~/.ssh/` directory with proper permissions (700)
- ✅ Creates `~/.ssh/authorized_keys` file with proper permissions (600)
- ✅ Sets correct ownership for SSH files
- ✅ Creates helper script for adding SSH keys

### Shell Environment
- ✅ Installs Zsh and Oh My Zsh framework
- ✅ Installs Zsh autosuggestions and syntax highlighting
- ✅ Copies root user's Zsh configuration (if available)
- ✅ Sets Zsh as default shell
- ✅ Adds comprehensive aliases for system administration

### Development Environment
- ✅ Installs NVM if detected on system
- ✅ Adds user to docker group (if Docker is installed)
- ✅ Configures development-friendly aliases

### System Integration
- ✅ Proper file ownership and permissions
- ✅ Inherits server configurations from root setup
- ✅ Administrative aliases for server management

## Usage Workflow

### 1. Create New User (run as existing sudo user)
```bash
# Create user with root privileges
sudo useradd -m -u 0 -o -g root newadmin

# Set password for new user
sudo passwd newadmin

# Optional: Add to sudoers for explicit sudo access
echo "newadmin ALL=(ALL:ALL) ALL" | sudo tee /etc/sudoers.d/newadmin
```

### 2. Login as New User
```bash
# Switch to new user
su - newadmin

# Or SSH directly (after adding SSH key)
ssh newadmin@your-server-ip
```

### 3. Run User Setup Script
```bash
curl -s https://raw.githubusercontent.com/vanphongngo/bash-utils/setup-server/setup-user.sh | bash
```

### 4. Add Your SSH Public Key
```bash
# Using the helper script (recommended)
./add-ssh-key.sh 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... your-email@example.com'

# Or manually
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... your-email@example.com' >> ~/.ssh/authorized_keys
```

### 5. Test SSH Access
```bash
# From your local machine
ssh newadmin@your-server-ip
```

## SSH Key Management

### Add SSH Key Methods

**Method 1: Using Helper Script**
```bash
# Add key directly
./add-ssh-key.sh 'ssh-rsa AAAAB3... your-email@example.com'

# Add from file
./add-ssh-key.sh ~/.ssh/id_rsa.pub
```

**Method 2: Manual Addition**
```bash
# Edit authorized_keys directly
vim ~/.ssh/authorized_keys

# Or append to file
echo 'your-public-key-here' >> ~/.ssh/authorized_keys
```

**Method 3: Copy from Another Server**
```bash
# Copy from another server where key is already set up
scp other-server:~/.ssh/authorized_keys ~/.ssh/
chmod 600 ~/.ssh/authorized_keys
```

### Generate SSH Key (if needed)
```bash
# Generate new key pair
ssh-keygen -t rsa -b 4096 -C "newadmin@$(hostname)"

# Display public key
cat ~/.ssh/id_rsa.pub
```

## Available Aliases

The script adds comprehensive aliases for system administration:

### Basic File Operations
```bash
ll      # ls -alF (detailed list)
la      # ls -A (show hidden files)
l       # ls -CF (compact format)
..      # cd .. (go up one directory)
...     # cd ../.. (go up two directories)
```

### Docker Management (if Docker installed)
```bash
d       # docker
dc      # docker-compose
dps     # docker ps (running containers)
di      # docker images
drmi    # docker rmi (remove images)
dstop   # Stop all running containers
drm     # Remove all containers
```

### Git Operations
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

### System Administration
```bash
sysinfo     # System hardware information
ports       # Show network ports
meminfo     # Memory usage information
psmem       # Processes sorted by memory usage
pscpu       # Processes sorted by CPU usage
logs        # Follow system logs (journalctl -f)
services    # List running services
listening   # Show listening ports
diskspace   # Disk usage summary
memtop      # Top processes by memory
cputop      # Top processes by CPU
```

## Security Considerations

### File Permissions
- SSH directory: `700` (owner read/write/execute only)
- authorized_keys: `600` (owner read/write only)
- All user files owned by the new user

### Root Privileges
Since the user was created with UID 0 (root privileges):
- User can perform system administration tasks
- Direct access to system files and configurations
- No need for `sudo` for most operations
- **Use responsibly** - this user has full system access

### SSH Security
```bash
# View current SSH configuration
cat /etc/ssh/sshd_config | grep -E "(PasswordAuthentication|PubkeyAuthentication|PermitRootLogin)"

# Recommended SSH security settings
sudo vim /etc/ssh/sshd_config
# Set: PasswordAuthentication no
# Set: PubkeyAuthentication yes
# Set: PermitRootLogin no

# Restart SSH service after changes
sudo systemctl restart sshd
```

## Troubleshooting

### SSH Key Issues

**1. Permission Denied (publickey)**
```bash
# Check SSH directory permissions
ls -la ~/.ssh/

# Should show:
# drwx------ .ssh/
# -rw------- authorized_keys

# Fix permissions if needed
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

**2. SSH Key Not Working**
```bash
# Check if key is in authorized_keys
cat ~/.ssh/authorized_keys

# Test SSH connection with verbose output
ssh -v newadmin@your-server-ip

# Check SSH server logs
sudo tail -f /var/log/auth.log
```

**3. Wrong Key Format**
```bash
# SSH keys should start with ssh-rsa, ssh-ed25519, etc.
# Each key should be on a single line
# Example format:
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... user@hostname
```

### Shell Issues

**1. Zsh Not Loading**
```bash
# Check current shell
echo $SHELL

# Manually switch to zsh
exec zsh

# Check if zsh is installed
which zsh
```

**2. Oh My Zsh Issues**
```bash
# Reinstall Oh My Zsh
rm -rf ~/.oh-my-zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

**3. Plugins Not Working**
```bash
# Check if plugins are installed
ls ~/.oh-my-zsh/custom/plugins/

# Reload zsh configuration
source ~/.zshrc
```

### Docker Access Issues

**1. Permission Denied for Docker**
```bash
# Check if user is in docker group
groups

# Should show 'docker' in the list
# If not, run:
usermod -aG docker $USER
# Then logout and login again
```

## Post-Setup Verification

### Test SSH Access
```bash
# From your local machine, test SSH key authentication
ssh newadmin@your-server-ip

# Should connect without password prompt
```

### Test Shell Environment
```bash
# Check shell
echo $SHELL
# Should show: /usr/bin/zsh

# Test aliases
ll
dps
gs
```

### Test System Access
```bash
# Test system administration capabilities
systemctl status nginx
docker ps
journalctl --since "10 minutes ago"
```

## Configuration Files

### Key Files Created/Modified
- `~/.ssh/authorized_keys` - SSH public keys
- `~/.zshrc` - Zsh configuration with aliases
- `~/.oh-my-zsh/` - Oh My Zsh framework
- `~/add-ssh-key.sh` - SSH key management helper

### Backup Files
- `~/.zshrc.backup.YYYYMMDD_HHMMSS` - Backup of original .zshrc (if existed)

## Advanced Usage

### Multiple SSH Keys
```bash
# Add multiple keys to authorized_keys
./add-ssh-key.sh 'ssh-rsa AAAAB3... laptop@user'
./add-ssh-key.sh 'ssh-rsa AAAAB3... desktop@user'
./add-ssh-key.sh 'ssh-rsa AAAAB3... mobile@user'
```

### Custom Aliases
```bash
# Add your own aliases to .zshrc
echo "alias mycommand='your-command-here'" >> ~/.zshrc
source ~/.zshrc
```

### Development Environment
```bash
# Install Node.js (if NVM was set up)
nvm install --lts
nvm use --lts

# Install global packages
npm install -g pm2 nodemon forever
```

## Security Best Practices

1. **Use SSH keys only** - Disable password authentication
2. **Regular key rotation** - Update SSH keys periodically
3. **Monitor access** - Check `/var/log/auth.log` regularly
4. **Limit key access** - Only add trusted public keys
5. **Use strong passphrases** - Protect private keys with passphrases

## Cleanup/Removal

If you need to remove the user setup:

```bash
# Remove Oh My Zsh
rm -rf ~/.oh-my-zsh

# Remove SSH setup
rm -rf ~/.ssh

# Change shell back to bash
chsh -s /bin/bash

# Remove from docker group
deluser $USER docker
```

## Support

For issues with this script:
1. Check the troubleshooting section above
2. Verify file permissions and ownership
3. Check system logs for error messages
4. Ensure the main server setup was completed first