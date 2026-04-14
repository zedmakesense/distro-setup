#!/usr/bin/env bash
set -euox pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

systemctl restart systemd-timesyncd
SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

echo "Choose one:"
select extra in "laptop" "bluetooth" "PC"; do
  [[ -n $extra ]] && break
  echo "Invalid choice."
done

case "$extra" in
laptop) lines='1p;2p;3p' ;;
bluetooth) lines='1p;2p' ;;
PC) lines='1p' ;;
esac
sed -n "$lines" pkgs.txt | tr ' ' '\n' >pkglist.txt

echo 'APT::Install-Recommends "false";' >/etc/apt/apt.conf.d/99no-recommends
xargs -a pkglist.txt apt install -y

if [[ "$extra" == "laptop" ]]; then
  cat <<'EOF' >/etc/tlp.d/01-custom.conf
# USB_AUTOSUSPEND=1
# USB_EXCLUDE_PHONE=1
# USB_EXCLUDE_PRINTER=1
# USB_EXCLUDE_WWAN=1
# USB_EXCLUDE_BTUSB=0
# USB_EXCLUDE_AUDIO=0

RUNTIME_PM_DRIVER_DENYLIST="amdgpu radeon nouveau nvidia"
RESTORE_DEVICE_STATE_ON_STARTUP=1

# DEVICES_TO_DISABLE_ON_STARTUP="bluetooth nfc wwan"

# DEVICES_TO_DISABLE_ON_BAT=""
# DEVICES_TO_ENABLE_ON_BAT=""

# DEVICES_TO_DISABLE_ON_AC=""
# DEVICES_TO_ENABLE_ON_AC=""

# DEVICES_TO_DISABLE_ON_LAN_CONNECT="wifi"
# DEVICES_TO_DISABLE_ON_WIFI_CONNECT="wwan"
EOF
fi

sed -i '/^timeout /d;/^editor /d' /boot/efi/loader/loader.conf
{
  echo "timeout 2"
  echo "editor no"
} >>/boot/efi/loader/loader.conf

echo "%wheel ALL=(ALL) ALL" >/etc/sudoers.d/wheel
echo "Defaults pwfeedback" >/etc/sudoers.d/pwfeedback
echo 'Defaults env_keep += "XDG_RUNTIME_DIR WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS WAYLAND_SOCKET"' >/etc/sudoers.d/wayland
echo 'Defaults secure_path="/nix/var/nix/profiles/default/bin:/home/piyush/local/state/nix/profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' > /etc/sudoers.d/nix-path
chmod 440 /etc/sudoers.d/*

usermod -aG sudo,adm,cdrom,plugdev,video,audio,input,netdev,libvirt,kvm,lpadmin piyush
# chown root:libvirt /var/lib/libvirt/images
# chmod 2775 /var/lib/libvirt/images

cat >/etc/udev/rules.d/90-backlight.rules <<'EOF'
SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="/bin/chown root:video /sys/class/backlight/%k/brightness"
SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="/bin/chmod 0664 /sys/class/backlight/%k/brightness"
EOF

udevadm control --reload-rules
udevadm trigger

# UFW setup
ufw allow in from 192.168.0.0/24
ufw allow out to 192.168.0.0/24

ufw allow in on virbr0 to any port 67 proto udp
ufw allow out on virbr0 to any port 68 proto udp
ufw allow in on virbr0 to any port 53 proto udp
ufw allow out on virbr0 to any port 53 proto udp
ufw allow in on virbr0 to any port 53 proto tcp
ufw allow out on virbr0 to any port 53 proto tcp
ufw route allow in on virbr0 out on eth0 from 192.168.122.0/24 to any port 53 proto udp

ufw default deny incoming
ufw default allow outgoing

ufw enable
ufw logging off

echo 'ListenAddress 127.0.0.1' >>/etc/ssh/sshd_config

mkdir -p /etc/systemd/resolved.conf.d
tee /etc/systemd/resolved.conf.d/disable-llmnr.conf >/dev/null <<'EOF'
[Resolve]
LLMNR=no
EOF

tee /etc/sysctl.d/99-hardening.conf >/dev/null <<'EOF'
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.unprivileged_bpf_disabled = 1

fs.protected_fifos = 2
fs.protected_regular = 2
fs.protected_symlinks = 1
fs.protected_hardlinks = 1

net.core.bpf_jit_harden = 1
EOF

sh <(curl -L https://nixos.org/nix/install) --daemon --yes
flatpak --system remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak --system install -y org.gtk.Gtk3theme.Adwaita-dark

loginctl enable-linger piyush
su - piyush -c '
  set -euox pipefail
  mkdir -p ~/Downloads ~/Desktop ~/Public ~/Templates ~/Videos ~/Pictures/Screenshots/temp ~/.config
  mkdir -p ~/Documents/projects ~/Documents/projects ~/Documents/personal/wiki
  mkdir -p ~/.local/bin ~/.cache/cargo-target ~/.local/state/bash ~/.local/state/zsh ~/.local/share/wineprefixes ~/.local/share/applications
  touch ~/.local/state/bash/history ~/.local/state/zsh/history

  git clone https://github.com/zedmakesense/scripts.git ~/Documents/projects/scripts
  git clone https://github.com/zedmakesense/distro-setup.git ~/Documents/projects/distro-setup
  git clone https://github.com/zedmakesense/GruvboxTheme.git ~/Documents/projects/GruvboxTheme

  ln -sf ~/Documents/projects/distro-setup/dotfiles/.bashrc ~/
  ln -s /usr/bin/fdfind ~/.local/bin/fd
  ln -s /usr/bin/batcat ~/.local/bin/bat

  for link in ~/Documents/projects/distro-setup/dotfiles/.config/*; do
    ln -sf "$link" ~/.config/
  done
  for link in ~/Documents/projects/distro-setup/dotfiles/copy/*; do
    cp -r "$link" ~/.config/
  done
  for link in ~/Documents/projects/scripts/bin/*; do
    ln -sf "$link" ~/.local/bin/
  done
  git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
  bash ~/.config/tmux/plugins/tpm/scripts/install_plugins.sh
  zoxide add ~/Documents/projects/distro-setup

  tmp=$(mktemp)
  head -n -3 ~/Documents/projects/distro-setup/dotfiles/.profile >| "$tmp"
  . "$tmp"

  mkdir -p ~/.local/share/fonts/iosevka
  cd ~/.local/share/fonts/iosevka
  curl -LO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/IosevkaTerm.zip
  unzip IosevkaTerm.zip
  rm IosevkaTerm.zip

  bash -c "$(curl -fsSL https://raw.githubusercontent.com/tomasklaen/uosc/HEAD/installers/unix.sh)"

  wget -O /tmp/zed.tar.gz "https://cloud.zed.dev/releases/stable/latest/download?asset=zed&arch=x86_64&os=linux&source=docs"
  tar -xvf /tmp/zed.tar.gz -C ~/.local
  ln -sf ~/.local/zed.app/bin/zed ~/.local/bin/zed
  cp ~/.local/zed.app/share/applications/* ~/.local/share/applications/
  sed -i "s|Icon=zed|Icon=$HOME/.local/zed.app/share/icons/hicolor/512x512/apps/zed.png|g" ~/.local/share/applications/dev.zed.Zed.desktop
  sed -i "s|Exec=zed|Exec=$HOME/.local/zed.app/libexec/zed-editor|g" ~/.local/share/applications/dev.zed.Zed.desktop

  rustup default stable
  cargo install typeman --no-default-features --features tui

  git clone https://github.com/vimwiki/vimwiki.git ~/.config/vim/pack/plugins/start/vimwiki
  git clone https://github.com/justinmk/vim-sneak.git ~/.config/vim/pack/plugins/start/vim-sneak
  git clone https://github.com/jasonccox/vim-wayland-clipboard.git ~/.config/vim/pack/plugins/start/vim-wayland-clipboard
  vim -c "helptags ~/.config/vim/pack/plugins/start/vimwiki/doc" -c quit

  podman create --name omni-tools --restart=no -p 127.0.0.1:1024:80 docker.io/iib0011/omni-tools:latest
  podman volume create convertx-data
  podman create --name convertx --restart=no -p 127.0.0.1:1026:3000 -v convertx-data:/app/data ghcr.io/c4illin/convertx:latest
  podman create --name excalidraw --restart=no -p 127.0.0.1:1027:80 docker.io/excalidraw/excalidraw:latest

  flatpak override --user --env=GTK_THEME=Adwaita-dark --env=QT_STYLE_OVERRIDE=Adwaita-Dark
'

cp /home/piyush/Documents/projects/scripts/kernal-param-gen.sh /usr/local/bin
. /usr/local/bin/kernal-param-gen.sh
cat >/etc/kernel/postinst.d/zzz-kernal-param-gen <<'EOF'
#!/usr/bin/env bash
/usr/local/bin/kernal-param-gen.sh
EOF
chmod +x /etc/kernel/postinst.d/zzz-kernal-param-gen

mkdir -p ~/.config ~/.local/state/bash ~/.local/state/zsh
touch ~/.local/state/zsh/history ~/.local/state/bash/history
ln -sf /home/piyush/Documents/projects/distro-setup/dotfiles/nix.conf /etc/nix/nix.conf
ln -sf /home/piyush/Documents/projects/distro-setup/dotfiles/.bashrc ~/
ln -sf /home/piyush/Documents/projects/distro-setup/dotfiles/.config/nvim/ ~/.config
ln -sf /home/piyush/Documents/projects/distro-setup/dotfiles/.config/vim/ ~/.config
cp -r /home/piyush/Documents/projects/distro-setup/dotfiles/copy/yazi/ ~/.config

tee /root/.bash_profile >/dev/null <<'EOF'
[[ -f ~/.bashrc ]] && . ~/.bashrc
EOF

export PATH=/root/.nix-profile/bin:$PATH
systemctl restart nix-daemon

nix profile add nixpkgs#yazi
sudo -iu piyush nix profile add \
  nixpkgs#hyprpicker \
  nixpkgs#bemoji \
  nixpkgs#wayscriber \
  nixpkgs#onlyoffice-desktopeditors \
  nixpkgs#typst \
  nixpkgs#clipse \
  nixpkgs#caligula \
  nixpkgs#air \
  nixpkgs#gofumpt \
  nixpkgs#go \
  nixpkgs#uv \
  nixpkgs#prettier \
  nixpkgs#go-migrate \
  nixpkgs#sql-formatter \
  nixpkgs#jdk17_headless \
  nixpkgs#opencode

for u in root piyush; do
  for p in \
    bennyyip/gruvbox-dark \
    dedukun/relative-motions \
    yazi-rs/plugins:full-border \
    yazi-rs/plugins:smart-paste \
    yazi-rs/plugins:zoom \
    yazi-rs/plugins:jump-to-char; do
    sudo -iu "$u" ya pkg add "$p" >/dev/null 2>&1 || true
  done
done

su - piyush -c '
ln -sf ~/Documents/projects/distro-setup/dotfiles/.profile ~/
'

corepack enable
corepack prepare pnpm@latest --activate

REPO="jgraph/drawio-desktop"
curl -s "https://api.github.com/repos/$REPO/releases/latest" |
  jq -r '.assets[].browser_download_url' |
  grep -E 'amd64.*\.deb$' |
  xargs -n1 wget
apt install -y ~/distro-setup/*deb

THEME_SRC="/home/piyush/Documents/projects/GruvboxTheme"
mkdir -p "/usr/share/Kvantum/Gruvbox"
cp "$THEME_SRC/gruvbox-kvantum.kvconfig" "/usr/share/Kvantum/Gruvbox/Gruvbox.kvconfig"
cp "$THEME_SRC/gruvbox-kvantum.svg" "/usr/share/Kvantum/Gruvbox/Gruvbox.svg"
cp -r "$THEME_SRC/themes/Gruvbox-Material-Dark" "/usr/share/themes"
cp -r "$THEME_SRC/icons/Gruvbox-Material-Dark" "/usr/share/icons"

mkdir -p /etc/firefox-esr/policies
ln -sf "/home/piyush/Documents/projects/distro-setup/dotfiles/firefox/policies.json" /etc/firefox-esr/policies/policies.json

TOTAL_MEM=$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)
ZRAM_SIZE=$((TOTAL_MEM / 2))

mkdir -p /etc/systemd/zram-generator.conf.d
{
  echo "[zram0]"
  echo "zram-size = ${ZRAM_SIZE}"
  echo "compression-algorithm = zstd"
  echo "swap-priority = 100"
  echo "fs-type = swap"
} >/etc/systemd/zram-generator.conf.d/00-zram.conf

systemctl start libvirtd
virsh net-autostart default

systemctl enable NetworkManager NetworkManager-dispatcher ufw fstrim.timer ipp-usb cups.socket docker.socket
systemctl disable NetworkManager-wait-online.service avahi-daemon dnsmasq bluetooth cups-browsed cups containerd libvirtd virtlogd docker
systemctl mask systemd-rfkill systemd-rfkill.socket
if [[ "$extra" == "laptop" ]]; then
  systemctl enable tlp
fi

mkdir -p /etc/systemd/logind.conf.d
printf '[Login]\nHandlePowerKey=ignore\n' >/etc/systemd/logind.conf.d/90-ignore-power.conf

apt remove --purge -y nano cron anacron apparmor
apt autoremove --purge -y
apt clean
