#!/usr/bin/env bash
#
# setup-kubectl-autocomplete.sh
# Detects your shell, installs any missing dependencies, and sets up
# kubectl autocompletion (bash, zsh or fish), plus an alias `k`.

set -euo pipefail

err() { printf "Error: %s\n" "$*" >&2; exit 1; }

if ! command -v kubectl &>/dev/null; then
  err "kubectl not found in PATH. Please install kubectl first."
fi

current_shell=$(basename "${SHELL:-}")

case "$current_shell" in
  bash)
    echo "Configuring kubectl autocomplete for Bash…"

    # 1) Ensure bash-completion is available
    if ! type _init_completion &>/dev/null; then
      echo "Installing bash-completion package…"
      if [[ "$(uname)" == "Darwin" ]]; then
        brew install bash-completion@2
        grep -qxF '[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && source "/usr/local/etc/profile.d/bash_completion.sh"' ~/.bash_profile \
          || echo '[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && source "/usr/local/etc/profile.d/bash_completion.sh"' >>~/.bash_profile
      else
        sudo apt-get update && sudo apt-get install -y bash-completion
      fi
    fi

    # 2) Enable for current session
    source <(kubectl completion bash)                    # loads __start_kubectl
    alias k=kubectl
    complete -o default -F __start_kubectl k

    # 3) Persist in ~/.bashrc
    rcfile=~/.bashrc

    # kubectl completion
    grep -qxF 'source <(kubectl completion bash)' "$rcfile" \
      || echo 'source <(kubectl completion bash)' >>"$rcfile"

    # alias
    grep -qxF 'alias k=kubectl' "$rcfile" \
      || echo 'alias k=kubectl' >>"$rcfile"

    # completion for alias k
    grep -qxF 'complete -o default -F __start_kubectl k' "$rcfile" \
      || echo 'complete -o default -F __start_kubectl k' >>"$rcfile"

    echo "Done. Restart your shell or run 'source $rcfile'."
    ;;

  zsh)
    echo "Configuring kubectl autocomplete for Zsh…"

    # compinit
    grep -q 'compinit' ~/.zshrc || echo "autoload -Uz compinit && compinit" >>~/.zshrc

    source <(kubectl completion zsh)
    echo "alias k=kubectl" >>~/.zshrc
    grep -qxF 'source <(kubectl completion zsh)' ~/.zshrc \
      || echo 'source <(kubectl completion zsh)' >>~/.zshrc

    echo "Done. Restart your shell or run 'source ~/.zshrc'."
    ;;

  fish)
    echo "Configuring kubectl autocomplete for Fish…"

    mkdir -p ~/.config/fish/completions
    kubectl completion fish > ~/.config/fish/completions/kubectl.fish
    # alias in fish
    grep -qxF 'alias k=kubectl' ~/.config/fish/config.fish \
      || echo 'alias k=kubectl' >>~/.config/fish/config.fish

    echo "Done. Restart your Fish shell."
    ;;

  *)
    err "Unsupported shell: $current_shell. Supported: bash, zsh, fish."
    ;;
esac
