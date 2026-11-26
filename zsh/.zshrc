# Mondlicht — Lean, Stylish Zsh + Starship

export PATH="$HOME/.local/bin:$PATH"
export EDITOR="vim"
export VISUAL="vim"
export LS_COLORS="di=1;34:ln=1;35:so=35:pi=33:ex=1;32:bd=34;46:cd=34;43:su=37;41:sg=30;43:tw=30;42:ow=34;42"

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE AUTO_CD

autoload -Uz compinit && compinit -d "$HOME/.zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

# Mondlicht + macOS-familiar aliases
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -lah --color=auto --group-directories-first'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias cls='clear'
alias ff='fastfetch'
alias wall='qs -c mondlicht ipc call shell toggleWallpaper'
alias pbcopy='wl-copy'
alias pbpaste='wl-paste'
alias open='xdg-open'

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#56607a'
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

if [[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    typeset -A ZSH_HIGHLIGHT_STYLES
    ZSH_HIGHLIGHT_STYLES[command]='fg=#adc6ff,bold'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=#adc6ff,bold'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=#debcdf,bold'
    ZSH_HIGHLIGHT_STYLES[function]='fg=#debcdf'
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#e07a8e,bold'
    ZSH_HIGHLIGHT_STYLES[path]='fg=#dce4f7,underline'
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#86c5a9'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#86c5a9'
fi

command -v starship >/dev/null && eval "$(starship init zsh)"

if [[ -n "${KITTY_WINDOW_ID:-}" && "${SHLVL:-1}" -eq 1 && -o interactive ]]; then
    command -v fastfetch >/dev/null && fastfetch
fi
