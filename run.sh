#!/usr/bin/env bash
set -e

kvantummanager --set Gruvbox

gsettings set org.gnome.desktop.interface gtk-theme 'Gruvbox-Material-Dark'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

gsettings set org.virt-manager.virt-manager.new-vm firmware 'uefi'
gsettings set org.virt-manager.virt-manager.new-vm cpu-default 'host-passthrough'
gsettings set org.virt-manager.virt-manager.new-vm graphics-type 'spice'

echo -n "/home/$USER/Documents/projects/default/dotfiles/firefox/ublock.txt" | wl-copy
dir=$(echo ~/.mozilla/firefox/*.default-esr)
ln -sf ~/Documents/projects/default/dotfiles/firefox/userESR.js "$dir/user.js"
mkdir $dir/bookmarkbackups/
cp -f ~/Documents/projects/default/dotfiles/firefox/book* "$dir/bookmarkbackups/"

gh auth login
gh extension install dlvhdr/gh-dash
