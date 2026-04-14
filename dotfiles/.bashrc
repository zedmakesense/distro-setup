[[ $- != *i* ]] && return
set -o noclobber

# set -o vi
# bind 'set show-mode-in-prompt on'
# bind 'set vi-ins-mode-string \1\e[6 q\2'
# bind 'set vi-cmd-mode-string \1\e[2 q\2'

export XDG_STATE_HOME="$HOME/.local/state"
export HISTFILE="$XDG_STATE_HOME/bash/history"
export HISTSIZE=1000
export HISTFILESIZE=2000
export HISTCONTROL="erasedups:ignoreboth"
export HISTIGNORE="&:[ ]*:exit:x:t:ls:l:ll:c:bg:fg:history:clear:cd"
# HISTTIMEFORMAT='%F %T '

shopt -s histverify
shopt -s histappend
shopt -s cmdhist

PROMPT_COMMAND='history -a'

shopt -s globstar
shopt -s checkwinsize
shopt -s dirspell
shopt -s cdspell

bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\e[C": forward-char'
bind '"\e[D": backward-char'

bind 'set meta-flag on'
bind 'set input-meta on'
bind 'set output-meta on'
bind 'set convert-meta off'
bind 'set skip-completed-text on'
bind 'set colored-stats on'
bind 'set completion-ignore-case on'
bind 'set show-all-if-unmodified on'
bind 'set show-all-if-ambiguous on'
bind 'set completion-prefix-display-length 2'
bind 'set completion-map-case on'
bind 'set page-completions off'
bind 'set mark-symlinked-directories on'

export XDG_CONFIG_HOME="$HOME/.config"
export BASH_COMPLETION_USER_FILE="$XDG_CONFIG_HOME/bash-completion/bash_completion"

PS1=$'\n\[\e[1;36m\][ \u@\h | \[\e[1;32m\]\w\[\e[1;36m\] ]\[\e[0m\]\n\[\e[38;5;51m\]>\[\e[0m\] '

__fzf_history__() {
  local selected
  selected=$(history | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]*//' | tac |
    fzf --height=40% --reverse --no-sort --bind=ctrl-r:toggle-sort)

  if [[ -n $selected ]]; then
    READLINE_LINE=$selected
    READLINE_POINT=${#READLINE_LINE}
  fi
}
bind -x '"\C-r":__fzf_history__'

y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd <"$tmp"
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

ex() {
  local archive="$1"
  local dest="${2:-.}"
  if [ ! -f "$archive" ]; then
    echo "'$archive' is not a valid file"
    return 1
  fi
  mkdir -p "$dest"
  case "$archive" in
    *.tar.bz2|*.tbz2) tar -xvjf "$archive" -C "$dest" ;;
    *.tar.gz|*.tgz)   tar -xvzf "$archive" -C "$dest" ;;
    *.tar.xz)         tar -xvJf "$archive" -C "$dest" ;;
    *.tar.zst)        tar --zstd -xvf "$archive" -C "$dest" ;;
    *.tar)            tar -xvf "$archive" -C "$dest" ;;
    *.bz2)            bunzip2 -vk "$archive" ;;
    *.gz)             gunzip -vk "$archive" ;;
    *.zip)            unzip -q "$archive" -d "$dest" ;;
    *.rar)            unrar x -v "$archive" "$dest" ;;
    *.7z)             7z x -bsp1 "$archive" -o"$dest" ;;
    *.Z)              uncompress -v "$archive" ;;
    *.deb)            ar xv "$archive" ;;
    *) echo "'$archive' cannot be extracted"; return 1 ;;
  esac
}

zd() {
  if [ $# -eq 0 ]; then
    builtin cd ~ || return
  elif [ -d "$1" ]; then
    builtin cd "$1" || return
  else
    z "$@" && printf "\U000F17A9 " && pwd || echo "Error: Directory not found"
  fi
}

alias l="eza -l -o --no-permissions --icons=always --group-directories-first"
alias ll="eza -la -o --no-permissions --icons=always --group-directories-first"
alias ltree="l --tree"
alias lltree="ll --tree"

alias mute="wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1"
alias unmute="wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0"

alias cp='cp -iv'
alias mv='mv -iv'
alias trash="trash -v"
alias copy="wl-copy"
alias nvim='NVIM_APPNAME=nvim-coding nvim'

alias rgWord='rg --no-heading --line-number --color=always --max-depth 1 "" | fzf --ansi | cut -d: -f1 | uniq | xargs -r vim'

alias cd="zd"
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias c="tput clear"
alias x="exit"
alias r="tput reset"

alias t="tmux"
alias tns="tmux new-session -s"
alias tks="tmux kill-session -t"
alias tas="tmux attach-session -t"
alias ta="tmux attach-session"
alias tls="tmux ls"

alias rsync="rsync -avh --progress"
alias rsync-ssh="rsync -avzh --progress -e ssh"
alias rsync-net="rsync -avzh --progress"

alias diffs='DELTA_FEATURES=+side-by-side git diff'
alias diffl='DELTA_FEATURES=+ git diff'

alias img="swayimg"
alias open="xdg-open"
alias xonotic="~/Desktop/Xonotic/xonotic-linux-sdl.sh"

source /usr/share/bash-completion/bash_completion
eval "$(zoxide init bash)"
