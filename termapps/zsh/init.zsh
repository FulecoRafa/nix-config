# Configuração interativa do zsh. Espera que quem a carrega já tenha feito
# `bindkey -v`, `compinit`, zsh-autosuggestions e fzf-tab; o
# zsh-syntax-highlighting deve vir depois deste arquivo.

# --- Opções -------------------------------------------------------------------
setopt interactive_comments # `# comentário` na linha de comando, como no bash
setopt no_nomatch           # glob sem resultado vira texto literal, como no bash
setopt extended_glob
setopt auto_pushd pushd_ignore_dups

# Histórico nativo continua existindo como fallback; a busca fica com o Atuin.
HISTFILE=${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history
[[ -d ${HISTFILE:h} ]] || mkdir -p ${HISTFILE:h}
HISTSIZE=100000
SAVEHIST=100000
setopt share_history extended_history hist_ignore_dups hist_ignore_space hist_reduce_blanks

# --- Modo vi --------------------------------------------------------------------
KEYTIMEOUT=1
bindkey -M viins '^?' backward-delete-char # apaga além do ponto em que entrou no insert
bindkey -M viins '^W' backward-kill-word
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^ ' autosuggest-accept

# Edita a linha atual no $EDITOR (Helix): Ctrl+E nos dois modos, `v` no normal.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M viins '^E' edit-command-line
bindkey -M vicmd '^E' edit-command-line
bindkey -M vicmd 'v' edit-command-line

# --- Completion -----------------------------------------------------------------
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' menu no # o menu é o fzf-tab
zstyle ':fzf-tab:*' switch-group '<' '>'
(( $+commands[eza] )) && zstyle ':fzf-tab:complete:(cd|z|__zoxide_z):*' fzf-preview 'eza -1 --color=always --icons=always $realpath'

# --- Histórico: fzf (Ctrl+T, Alt+C) e Atuin (Ctrl+R, sobrescreve o do fzf) ------
if (( $+commands[fzf] )); then
  source <(fzf --zsh)
  # O `fzf --zsh` toma o Tab para o gatilho `**`; devolve ao fzf-tab.
  (( $+functions[fzf-tab-complete] )) && bindkey -M viins '^I' fzf-tab-complete
fi

if (( $+commands[atuin] )); then
  eval "$(atuin init zsh --disable-up-arrow)"

  # Sugestão inline: primeiro o que já foi executado neste diretório, depois o
  # histórico global.
  _zsh_autosuggest_strategy_atuin_dir() {
    suggestion=$(ATUIN_QUERY="$1" atuin search --cmd-only --limit 1 \
      --search-mode prefix --filter-mode directory 2>/dev/null)
  }
  ZSH_AUTOSUGGEST_STRATEGY=(atuin_dir atuin)
else
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi
ZSH_AUTOSUGGEST_USE_ASYNC=1

# --- Prompt de duas linhas no estilo "nim" --------------------------------------
#   ┬─[user@host:~/path]─[HH:MM:SS]─[V:venv]─[G:branch●]
#   ╰─>$ [I]
autoload -Uz add-zsh-hook add-zle-hook-widget

_nim_prompt_precmd() {
  local last=$? retc=green
  (( last )) && retc=red

  local venv='' git='' branch
  [[ -n $VIRTUAL_ENV ]] && venv="%f─%B%F{green}[%b%fV:%F{$retc}${VIRTUAL_ENV:t}%B%F{green}]%b"
  if branch=$(git branch --show-current 2>/dev/null) && [[ -n $branch ]]; then
    [[ -n $(git status --porcelain 2>/dev/null | head -1) ]] && branch+='●'
    git="%f─%B%F{green}[%b%fG:%F{$retc}${branch//\%/%%}%B%F{green}]%b"
  fi

  _nim_prompt_top="%F{$retc}┬─%B%F{green}[%(!.%F{red}.%F{yellow})%n%F{white}@%F{${${SSH_CLIENT:+cyan}:-blue}}%m%F{white}:%~%F{green}]%b%f─%B%F{green}[%b%f%D{%H:%M:%S}%B%F{green}]%b${venv}${git}%f"
  _nim_prompt_bottom="%F{$retc}╰─>%B%F{red}\$%b%f "
  _nim_prompt_render viins
}
# Roda antes dos outros hooks (Atuin etc.) para ler o $? do comando do usuário.
precmd_functions=(_nim_prompt_precmd ${precmd_functions:#_nim_prompt_precmd})

_nim_prompt_render() {
  local mode='%B%F{green}[I]%b%f '
  [[ $1 == vicmd ]] && mode='%B%F{red}[N]%b%f '
  PROMPT="${_nim_prompt_top}"$'\n'"${_nim_prompt_bottom}${mode}"
}

# Atualiza o indicador [I]/[N] e o formato do cursor a cada troca de modo.
_nim_prompt_keymap() {
  _nim_prompt_render $KEYMAP
  zle reset-prompt
  [[ $KEYMAP == vicmd ]] && print -n '\e[2 q' || print -n '\e[6 q'
}
_nim_prompt_line_init() { print -n '\e[6 q' }
add-zle-hook-widget keymap-select _nim_prompt_keymap
add-zle-hook-widget line-init _nim_prompt_line_init
PROMPT2='::: '

# --- Aliases --------------------------------------------------------------------
if (( $+commands[eza] )); then
  alias ls='eza --icons=auto'
  alias ll='eza --icons=auto -l'
  alias la='eza --icons=auto -la'
fi
alias dev='cd ~/Documents/Dev'

# Ajustes exclusivos desta máquina (SDKs, sockets, etc.), fora do repositório.
[[ -r $HOME/.zshrc.local ]] && source $HOME/.zshrc.local
