export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export XCOMPOSEFILE="$XDG_CONFIG_HOME/X11/xcompose"

export CARGO_HOME="$XDG_DATA_HOME/cargo"
export CARGO_TARGET_DIR="$XDG_CACHE_HOME/cargo-target"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"

export GOPATH="$XDG_DATA_HOME/go"

export JAVA_HOME="$HOME/.nix-profile"
export _JAVA_OPTIONS="-Djava.util.prefs.userRoot=$XDG_CONFIG_HOME/java"
export _JAVA_AWT_WM_NONREPARENTING=1

export PYTHON_HISTORY="$XDG_STATE_HOME/python_history"
export PYTHONPYCACHEPREFIX="$XDG_CACHE_HOME/python"
export PYTHONUSERBASE="$XDG_DATA_HOME/python"
export PIP_CONFIG_FILE="$XDG_CONFIG_HOME/pip/pip.conf"
export WORKON_HOME="$XDG_DATA_HOME/virtualenvs"

export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export PNPM_HOME="$XDG_DATA_HOME/pnpm"

export WGETRC="$XDG_CONFIG_HOME/wget/wgetrc"
export WINEPREFIX="$XDG_DATA_HOME/wineprefixes/default"
export PARALLEL_HOME="$XDG_CONFIG_HOME/parallel"
export W3M_DIR="$XDG_STATE_HOME/w3m"
export NSS_DB_DIR="$XDG_DATA_HOME/pki/nssdb"
export TMUX_TMPDIR="$XDG_RUNTIME_DIR"

export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"

export XDG_CURRENT_DESKTOP="sway"
export XDG_SESSION_DESKTOP="sway"
export XDG_SESSION_TYPE="wayland"

export QT_QPA_PLATFORM="wayland"
export QT_QPA_PLATFORMTHEME="qt6ct"
export QT_STYLE_OVERRIDE="kvantum"
export QT_QUICK_BACKEND=software

export GTK_USE_PORTAL=1

export TERMINAL="foot"
export TERM="xterm-256color"
export COLORTERM="truecolor"

export EDITOR="vim"
export VISUAL="vim"
export SYSTEMD_EDITOR="vim"
export MANPAGER="vim -M +MANPAGER -c 'set ft=man nomod nolist nonu noma' -"

path_prepend() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        PATH="$1:$PATH"
    fi
}

path_prepend "$HOME/.local/bin"
path_prepend "$HOME/bin"
path_prepend "$GOPATH/bin"
path_prepend "$CARGO_HOME/bin"
path_prepend "$PNPM_HOME"
path_prepend "$HOME/.local/state/nix/profile/bin"
path_prepend "/nix/var/nix/profiles/default/bin"

export PATH

. "$HOME/.bashrc"
if [ "$USER" = "piyush" ] && [ -z "${WAYLAND_DISPLAY-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec sway
fi
