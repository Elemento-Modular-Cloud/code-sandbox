sudo dnf install -y zsh, zsh-syntax-highlighting 
sudo chsh -s /bin/zsh elemento-root
curl -sS https://starship.rs/install.sh | sh

echo "source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ${ZDOTDIR:-$HOME}/.zshrc
echo 'eval "$(starship init zsh)"' >> ${ZDOTDIR:-$HOME}/.zshrc

# Add your starship configuration at ~/.config/starship.toml
