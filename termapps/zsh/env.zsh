# Ambiente portátil, carregado por todo zsh (inclusive não interativo).
# É idempotente: o .zshrc do macOS o carrega de novo depois do path_helper.
export EDITOR=hx
export VISUAL=hx
export VIRTUAL_ENV_DISABLE_PROMPT=true

if [[ -x /opt/homebrew/bin/brew ]]; then
  export HOMEBREW_PREFIX=/opt/homebrew
  export HOMEBREW_CELLAR=/opt/homebrew/Cellar
  export HOMEBREW_REPOSITORY=/opt/homebrew
fi

[[ -d $HOME/.pyenv ]] && export PYENV_ROOT=$HOME/.pyenv
if [[ -d $HOME/.swiftly ]]; then
  export SWIFTLY_HOME_DIR=$HOME/.swiftly
  export SWIFTLY_BIN_DIR=$HOME/.swiftly/bin
fi

# Acrescenta apenas diretórios que existem na máquina atual, sem duplicar.
typeset -U path
path=(
  $HOME/.local/bin
  $HOME/.cargo/bin
  $HOME/.bun/bin
  $HOME/.ghcup/bin
  $HOME/.pyenv/bin
  $HOME/.swiftly/bin
  $HOME/.nix-profile/bin
  /opt/homebrew/bin
  /opt/homebrew/sbin
  /Applications/Docker.app/Contents/Resources/bin
  $path
)
path=(${^path}(N-/))
