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
select hardware in "vm" "hardware"; do
  [[ -n $hardware ]] && break
  echo "Invalid choice. Please select 1 for vm or 2 for hardware."
done

if [[ "$hardware" == "hardware" ]]; then
  echo "Choose one:"
  select extra in "laptop" "bluetooth" "none"; do
    [[ -n $extra ]] && break
    echo "Invalid choice."
  done
else
  extra="none"
fi

case "$hardware" in
vm)
  sed -n '1p' pkgs.txt | tr ' ' '\n' | grep -v '^$' >>pkglist.txt
  ;;
hardware)
  sed -n '1p;2p' pkgs.txt | tr ' ' '\n' | grep -v '^$' >>pkglist.txt
  ;;
esac

# For hardware:max, add lines 5 and/or 6 based on $extra
if [[ "$hardware" == "hardware" ]]; then
  case "$extra" in
  laptop)
    sed -n '3p;4p' pkgs.txt | tr ' ' '\n' | grep -v '^$' >>pkglist.txt
    ;;
  bluetooth)
    sed -n '3p' pkgs.txt | tr ' ' '\n' | grep -v '^$' >>pkglist.txt
    ;;
  none) ;;
  esac
fi

xargs -a pkglist.txt apt install -y

if [[ "$extra" == "laptop" ]]; then
  cat <<'EOF' >/etc/tlp.d/01-custom.conf
# -------------------------
# USB Power Management
# -------------------------
USB_AUTOSUSPEND=1
USB_EXCLUDE_PHONE=1
# Allow TLP to touch Bluetooth
USB_EXCLUDE_BTUSB=0
USB_EXCLUDE_WWAN=1
USB_EXCLUDE_AUDIO=1
USB_EXCLUDE_PRINTER=1

# -------------------------
# PCIe / Runtime Power Management
# -------------------------
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto
RUNTIME_PM_DRIVER_DENYLIST="amdgpu nouveau nvidia r8169"

# -------------------------
# AHCI / SATA
# -------------------------
AHCI_RUNTIME_PM_ON_AC=auto
AHCI_RUNTIME_PM_ON_BAT=auto
AHCI_RUNTIME_PM_TIMEOUT=15
SATA_LINKPWR_ON_AC="max_performance"
SATA_LINKPWR_ON_BAT="med_power_with_dipm"

# -------------------------
# Sound / Audio
# -------------------------
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=0
SOUND_POWER_SAVE_CONTROLLER=N

# -------------------------
# Wi-Fi
# -------------------------
# WIFI_PWR_ON_AC=off
# WIFI_PWR_ON_BAT=off

# -------------------------
# Radio Device Wizard (RDW)
# -------------------------
DEVICES_TO_DISABLE_ON_STARTUP="bluetooth nfc wwan wifi"

# DEVICES_TO_DISABLE_ON_BAT=""
# DEVICES_TO_ENABLE_ON_BAT=""

# DEVICES_TO_DISABLE_ON_AC=""
# DEVICES_TO_ENABLE_ON_AC=""

# DEVICES_TO_DISABLE_ON_LAN_CONNECT="wifi"
# DEVICES_TO_DISABLE_ON_WIFI_CONNECT="wwan"
EOF
fi

scaling_f="/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver"
pstate_supported=false
driver=""
if [ -d /sys/devices/system/cpu/intel_pstate ]; then
  driver="intel_pstate"
  pstate_supported=true
elif [ -d /sys/devices/system/cpu/amd_pstate ] || [ -d /sys/devices/system/cpu/amd-pstate ]; then
  # kernel docs and kernels may expose amd_pstate/amd-pstate; accept either
  driver="amd_pstate"
  pstate_supported=true
elif [ -r "$scaling_f" ]; then
  # fallback: read scaling_driver and normalise
  rawdrv=$(cat "$scaling_f" 2>/dev/null || true)
  case "$rawdrv" in
  *intel*)
    driver="intel_pstate"
    pstate_supported=true
    ;;
  *amd*)
    driver="amd_pstate"
    pstate_supported=true
    ;;
  *) driver="$rawdrv" ;;
  esac
fi

pstate_param=""
if [ "$pstate_supported" = true ]; then
  if [ "$driver" = "intel_pstate" ]; then
    pstate_param="intel_pstate=active"
  elif [ "$driver" = "amd_pstate" ]; then
    pstate_param="amd_pstate=active"
  fi
fi

extra_params="fsck.repair=yes zswap.enabled=0"
[ -n "$pstate_param" ] && extra_params="$extra_params $pstate_param"

sed -i '/^timeout /d;/^editor /d' /boot/efi/loader/loader.conf
{
  echo "timeout 2"
  echo "editor no"
} >>/boot/efi/loader/loader.conf

for f in /boot/efi/loader/entries/*; do
  opts=$(sed -n 's/^options[[:space:]]\+//p' "$f")

  for p in $extra_params; do
    echo "$opts" | grep -Fq "$p" ||
      sed -i "/^options[[:space:]]\+/ s/$/ $p/" "$f"
  done
done

echo "%wheel ALL=(ALL) ALL" >/etc/sudoers.d/wheel
echo "Defaults pwfeedback" >/etc/sudoers.d/pwfeedback
echo 'Defaults env_keep += "SYSTEMD_EDITOR XDG_RUNTIME_DIR WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS WAYLAND_SOCKET"' >/etc/sudoers.d/wayland
echo 'Defaults secure_path="/nix/var/nix/profiles/default/bin:/home/piyush/local/state/nix/profile/bin"' | sudo tee /etc/sudoers.d/nix-path
chmod 440 /etc/sudoers.d/*
if [[ "$hardware" == "hardware" ]]; then
  usermod -aG libvirt,kvm,lpadmin piyush
  chown root:libvirt /var/lib/libvirt/images
  chmod 2775 /var/lib/libvirt/images
fi
usermod -aG sudo,adm,cdrom,plugdev,video,audio,input,netdev,docker piyush

# UFW setup
ufw allow in from 192.168.0.0/24
ufw allow out to 192.168.0.0/24

ufw deny 631/tcp

ufw allow in on virbr0 to any port 67 proto udp
ufw allow out on virbr0 to any port 68 proto udp
ufw allow in on virbr0 to any port 53 proto udp
ufw allow out on virbr0 to any port 53 proto udp
ufw allow in on virbr0 to any port 53 proto tcp
ufw allow out on virbr0 to any port 53 proto tcp
ufw route allow in on virbr0 out on eth0 from 192.168.122.0/24 to any port 53 proto udp

# ufw default allow routed
ufw default deny incoming
ufw default allow outgoing

ufw enable
ufw logging on

echo 'ListenAddress 127.0.0.1' >>/etc/ssh/sshd_config

mkdir -p /etc/systemd/resolved.conf.d
tee /etc/systemd/resolved.conf.d/disable-llmnr.conf >/dev/null <<'EOF'
[Resolve]
LLMNR=no
EOF

# apparmour stuff
# aa-enforce /etc/apparmor.d/Discord
# aa-enforce /etc/apparmor.d/steam
# aa-enforce /etc/apparmor.d/signal-desktop
# aa-enforce /etc/apparmor.d/firefox
# aa-enforce /etc/apparmor.d/flatpak
# aa-enforce /etc/apparmor.d/loupe

tee /etc/sysctl.d/99-hardening.conf >/dev/null <<'EOF'
# networking
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# kernel hardening
kernel.kptr_restrict = 2

# file protections
fs.protected_fifos = 2

# bpf jit harden (if present)
net.core.bpf_jit_harden = 2
EOF

sh <(curl -L https://nixos.org/nix/install) --daemon --yes
flatpak --system remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak --system install -y org.gtk.Gtk3theme.Adwaita-dark
loginctl enable-linger piyush
su - piyush -c '
  mkdir -p ~/Downloads ~/Desktop ~/Public ~/Templates ~/Videos ~/Pictures/Screenshots/temp ~/.config
  mkdir -p ~/Documents/projects/default ~/Documents/projects ~/Documents/personal/wiki
  mkdir -p ~/.local/bin ~/.cache/cargo-target ~/.local/state/bash ~/.local/state/zsh ~/.local/share/wineprefixes ~/.local/share/applications
  touch ~/.local/state/bash/history ~/.local/state/zsh/history

  echo "if [ -z \"\$WAYLAND_DISPLAY\" ] && [ \"\$(tty)\" = \"/dev/tty1\" ]; then
    exec sway
fi" >> ~/.profile

  git clone https://github.com/zedmakesense/scripts.git ~/Documents/projects/default/scripts
  git clone https://github.com/zedmakesense/dotfiles.git ~/Documents/projects/default/dotfiles
  git clone https://github.com/zedmakesense/debsetup.git ~/Documents/projects/default/debsetup
  git clone https://github.com/zedmakesense/notes.git ~/Documents/projects/default/notes
  git clone https://github.com/zedmakesense/GruvboxTheme.git ~/Documents/projects/default/GruvboxTheme

  cp ~/Documents/projects/default/dotfiles/pics/* ~/Pictures/
  ln -sf ~/Documents/projects/default/dotfiles/.bashrc ~/.bashrc

  for link in ~/Documents/projects/default/dotfiles/.config/*; do
    ln -sf "$link" ~/.config/
  done
  for link in ~/Documents/projects/default/dotfiles/copy/*; do
    cp -r "$link" ~/.config/
  done
  for link in ~/Documents/projects/default/scripts/bin/*; do
    ln -sf "$link" ~/.local/bin/
  done
  git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
  /home/piyush/Documents/projects/default/dotfiles/.config/tmux/plugins/tpm/scripts/install_plugins.sh
  zoxide add /home/piyush/Documents/projects/default/debsetup
  source ~/.bashrc

  mkdir -p ~/.local/share/fonts/iosevka
  cd ~/.local/share/fonts/iosevka
  curl -LO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/IosevkaTerm.zip
  unzip IosevkaTerm.zip
  rm IosevkaTerm.zip

  wget -O /tmp/zed.tar.gz "https://cloud.zed.dev/releases/stable/latest/download?asset=zed&arch=x86_64&os=linux&source=docs"
  tar -xvf /tmp/zed.tar.gz -C ~/.local
  ln -sf ~/.local/zed.app/bin/zed ~/.local/bin/zed
  cp ~/.local/zed.app/share/applications/* ~/.local/share/applications/
  sed -i "s|Icon=zed|Icon=$HOME/.local/zed.app/share/icons/hicolor/512x512/apps/zed.png|g" ~/.local/share/applications/dev.zed.Zed.desktop
  sed -i "s|Exec=zed|Exec=$HOME/.local/zed.app/libexec/zed-editor|g" ~/.local/share/applications/dev.zed.Zed.desktop

  gh extension install dlvhdr/gh-dash
  rustup default stable
  cargo install typeman --no-default-features --features tui
  go install golang.org/x/tools/cmd/goimports@latest

  podman create --name omni-tools --restart=no -p 127.0.0.1:1024:80 docker.io/iib0011/omni-tools:latest
  podman create --name bentopdf --restart=no -p 127.0.0.1:1025:8080 docker.io/bentopdf/bentopdf:latest
  podman volume create convertx-data
  podman create --name convertx --restart=no -p 127.0.0.1:1026:3000 -v convertx-data:/app/data:Z ghcr.io/c4illin/convertx
  podman create --name excalidraw --restart=no -p 127.0.0.1:1027:80 docker.io/excalidraw/excalidraw:latest

  flatpak override --user --env=GTK_THEME=Adwaita-dark --env=QT_STYLE_OVERRIDE=Adwaita-Dark
'

mkdir -p ~/.config ~/.local/state/bash ~/.local/state/zsh
echo '[[ -f ~/.bashrc ]] && . ~/.bashrc' >~/.bash_profile
touch ~/.local/state/zsh/history ~/.local/state/bash/history
ln -sf /home/piyush/Documents/projects/default/dotfiles/nix.conf /etc/nix/nix.conf
ln -sf /home/piyush/Documents/projects/default/dotfiles/.bashrc ~/.bashrc
ln -sf /home/piyush/Documents/projects/default/dotfiles/.config/nvim/ ~/.config

source ~/.bashrc
systemctl restart nix-daemon

sudo -iu piyush nix profile add \
  nixpkgs#hyprpicker \
  nixpkgs#bemoji \
  nixpkgs#wayscriber \
  nixpkgs#lazydocker \
  nixpkgs#easyeffects \
  nixpkgs#rnnoise \
  nixpkgs#onlyoffice-desktopeditors \
  nixpkgs#clipse \
  nixpkgs#caligula \
  nixpkgs#air \
  nixpkgs#templ \
  nixpkgs#htmx-lsp \
  nixpkgs#go \
  nixpkgs#gotools \
  nixpkgs#uv \
  nixpkgs#prettier \
  nixpkgs#shfmt \
  nixpkgs#go-migrate \
  nixpkgs#opencode \
  nixpkgs#javaPackages.compiler.temurin-bin.jre-17

nix profile add nixpkgs#yazi

for u in root piyush; do
  for p in \
    bennyyip/gruvbox-dark \
    dedukun/relative-motions \
    yazi-rs/plugins:full-border \
    yazi-rs/plugins:smart-paste \
    yazi-rs/plugins:zoom \
    yazi-rs/plugins:jump-to-char
  do
    sudo -iu "$u" ya pkg add "$p" >/dev/null 2>&1 || true
  done
done

corepack enable
corepack prepare pnpm@latest --activate

REPO="jgraph/drawio-desktop"
curl -s "https://api.github.com/repos/$REPO/releases/latest" |
  jq -r '.assets[].browser_download_url' |
  grep -E 'amd64.*\.deb$' |
  xargs -n1 wget
apt install -y ~/debsetup/*deb

git clone --depth 1 https://gitlab.com/ananicy-cpp/ananicy-cpp.git
cd ananicy-cpp
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DENABLE_SYSTEMD=ON -DUSE_BPF_PROC_IMPL=ON -DWITH_BPF=ON
cmake --build build --target ananicy-cpp
cmake --install build --component Runtime

THEME_SRC="/home/piyush/Documents/projects/default/GruvboxTheme"
THEME_DEST="/usr/share/Kvantum/Gruvbox"
mkdir -p "$THEME_DEST"
cp "$THEME_SRC/gruvbox-kvantum.kvconfig" "$THEME_DEST/Gruvbox.kvconfig"
cp "$THEME_SRC/gruvbox-kvantum.svg" "$THEME_DEST/Gruvbox.svg"

THEME_DEST="/usr/share"
cp -r "$THEME_SRC/themes/Gruvbox-Material-Dark" "$THEME_DEST/themes"
cp -r "$THEME_SRC/icons/Gruvbox-Material-Dark" "$THEME_DEST/icons"

git clone --depth=1 https://github.com/RogueScholar/ananicy.git
git clone --depth=1 https://github.com/CachyOS/ananicy-rules.git
mkdir -p /etc/ananicy.d/roguescholar /etc/ananicy.d/zz-cachyos
cp -r ananicy/ananicy.d/* /etc/ananicy.d/roguescholar/
cp -r ananicy-rules/00-default/* /etc/ananicy.d/zz-cachyos/
cp -r ananicy-rules/00-types.types /etc/ananicy.d/zz-cachyos/
cp -r ananicy-rules/00-cgroups.cgroups /etc/ananicy.d/zz-cachyos/
tee /etc/ananicy.d/ananicy.conf >/dev/null <<'EOF'
check_freq = 15
cgroup_load = false
type_load = true
rule_load = true
apply_nice = true
apply_latnice = true
apply_ionice = true
apply_sched = true
apply_oom_score_adj = true
apply_cgroup = true
loglevel = info
log_applied_rule = false
cgroup_realtime_workaround = false
EOF

mkdir -p /etc/firefox/policies
ln -sf "/home/piyush/Documents/projects/default/dotfiles/firefox/policies.json" /etc/firefox/policies/policies.json

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

if [[ "$hardware" == "hardware" ]]; then
  systemctl enable fstrim.timer libvirtd.socket ipp-usb docker.socket
  systemctl disable docker.service dnsmasq bluetooth avahi-daemon
fi
if [[ "$extra" == "laptop" ]]; then
  systemctl enable tlp
fi
systemctl enable NetworkManager NetworkManager-dispatcher ufw ananicy-cpp
systemctl mask systemd-rfkill systemd-rfkill.socket apparmor
systemctl disable NetworkManager-wait-online.service apparmor

mkdir -p /etc/systemd/logind.conf.d
printf '[Login]\nHandlePowerKey=ignore\n' >/etc/systemd/logind.conf.d/90-ignore-power.conf

apt remove --purge -y vim-common vim-tiny libsystemd-dev libbpf-dev libelf-dev bpftool nano vlc
apt autoremove --purge -y
apt clean
