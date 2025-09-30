#!/bin/bash

# 1. Install zsh
sudo apt update && sudo apt install -y zsh git curl

# 2. Install Oh My Zsh (plugin manager & config framework)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# 3. Install zsh-autosuggestions plugin
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# 4. Install zsh-syntax-highlighting plugin (recommended together)
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# 5. Enable the plugins: edit ~/.zshrc
sed -i 's/^plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

# 6. Apply the changes
source ~/.zshrc

# 7. (Optional) Make zsh your default shell
chsh -s $(which zsh)
