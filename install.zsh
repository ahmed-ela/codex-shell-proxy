#!/usr/bin/env zsh

emulate -L zsh
setopt local_options pipefail

repo_dir="${0:A:h}"
bin_dir="$HOME/.local/bin"
zsh_dir="$HOME/.config/codex-shell-proxy"
zshrc="$HOME/.zshrc"

mkdir -p -- "$bin_dir" "$zsh_dir"

ln -sf -- "$repo_dir/bin/codex-shell-proxy" "$bin_dir/codex-shell-proxy"
ln -sf -- "$repo_dir/bin/codex-shell-daemon" "$bin_dir/codex-shell-daemon"
ln -sf -- "$repo_dir/bin/showme" "$bin_dir/showme"
ln -sf -- "$repo_dir/bin/test-codex-shell-fast-path" "$bin_dir/test-codex-shell-fast-path"
ln -sf -- "$repo_dir/bin/test-codex-shell-router" "$bin_dir/test-codex-shell-router"
ln -sf -- "$repo_dir/zsh/codex-shell.zsh" "$zsh_dir/codex-shell.zsh"

source_line='[[ -r "$HOME/.config/codex-shell-proxy/codex-shell.zsh" ]] && source "$HOME/.config/codex-shell-proxy/codex-shell.zsh"'

touch -- "$zshrc"
if ! grep -Fqx -- "$source_line" "$zshrc"; then
  {
    printf '\n# codex-shell-proxy optional shell helpers\n'
    printf '%s\n' "$source_line"
  } >> "$zshrc"
fi

print -r -- "Installed codex-shell-proxy."
print -r -- "Open a new terminal, or run: source ~/.zshrc"
print -r -- "Test with: test-codex-shell-router"
