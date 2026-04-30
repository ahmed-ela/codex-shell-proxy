# Natural-language Enter proxy for zsh. Valid shell commands still execute
# normally; otherwise the line is sent to Codex as a terminal request.

if [[ -o interactive ]]; then
  if [[ "${CODEX_SHELL_WARM:-1}" != "0" && "${CODEX_SHELL_AUTOSTART:-1}" != "0" ]] && command -v codex-shell-daemon >/dev/null 2>&1; then
    codex-shell-daemon start --quiet >/dev/null 2>&1 &!
  fi

  __codex_shell_line_is_direct_command() {
    emulate -L zsh
    setopt local_options extended_glob

    local line="$*"
    line="${line//$'\r'/$'\n'}"

    [[ -z "${line//[[:space:]]/}" ]] && return 0
    [[ "$line" == *$'\n'* ]] && return 0
    [[ "$line" == [[:space:]]#\#* ]] && return 0

    command zsh -n -c "$line" >/dev/null 2>&1 || return 1

    local -a words
    words=("${(@z)line}") || return 1

    local word cmd=''
    for word in "${words[@]}"; do
      [[ "$word" == [A-Za-z_][A-Za-z0-9_]#=* ]] && continue
      cmd="$word"
      break
    done

    [[ -z "$cmd" ]] && return 0

    # macOS ships old Unix tools such as `what`; treat common question-word
    # phrases as natural language unless the user gives shell-shaped syntax.
    case "$cmd" in
      what|why|how|who|when|where)
        if (( ${#words[@]} > 1 )) && [[ "$line" != *[-./~=\|';'\"\`\$\<\>\&\(\)\[\]\{\}]* ]]; then
          return 1
        fi
        ;;
    esac

    case "$cmd" in
      if|then|else|elif|fi|for|while|until|do|done|case|esac|function|select|repeat|coproc|foreach|end|time|\{|\(|\!|\[\[|\[|\
      cd|pwd|exit|return|export|alias|unalias|source|.|set|unset|typeset|local|autoload|bindkey|zle|jobs|fg|bg|kill|wait|\
      true|false|test|eval|emulate|fc|history|dirs|pushd|popd|hash|rehash|command|builtin|exec|noglob)
        return 0
        ;;
    esac

    if [[ "$cmd" == */* ]]; then
      [[ -e "$cmd" ]] && return 0
      return 1
    fi

    whence -w -- "$cmd" >/dev/null 2>&1
  }

  __codex_shell_should_proxy_line() {
    emulate -L zsh

    [[ "${CODEX_SHELL_ENTER:-1}" == "0" ]] && return 1
    command -v codex-shell-proxy >/dev/null 2>&1 || return 1
    __codex_shell_line_is_direct_command "$*" && return 1
    return 0
  }

  __codex_shell_accept_line() {
    emulate -L zsh

    local line="$BUFFER"
    if __codex_shell_should_proxy_line "$line"; then
      print -sr -- "$line"
      BUFFER=''
      CURSOR=0
      zle -I
      print -r -- "$line"
      print -r -- ''
      codex-shell-proxy -- "$line"
      local proxy_exit=$?
      print -r -- ''
      zle reset-prompt
      return "$proxy_exit"
    fi

    zle .accept-line
  }

  zle -N accept-line __codex_shell_accept_line
fi
