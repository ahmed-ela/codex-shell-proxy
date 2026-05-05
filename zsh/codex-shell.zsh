# Optional natural-language Enter proxy for zsh. The default interface is the
# explicit `showme` command so normal Enter has no router overhead.

if [[ -o interactive ]]; then
  if [[ "${CODEX_SHELL_WARM:-1}" != "0" && "${CODEX_SHELL_AUTOSTART:-0}" == "1" ]] && command -v codex-shell-daemon >/dev/null 2>&1; then
    codex-shell-daemon start --quiet >/dev/null 2>&1 &!
  fi

  typeset -gA __codex_shell_jj_alias_targets
  typeset -gi __codex_shell_jj_alias_targets_loaded=0
  typeset -g __codex_shell_jj_root_check_pwd=''
  typeset -gi __codex_shell_jj_root_active=0

  __codex_shell_load_jj_alias_targets() {
    emulate -L zsh
    setopt local_options extended_glob

    (( __codex_shell_jj_alias_targets_loaded )) && return 0
    __codex_shell_jj_alias_targets=()

    command -v jj >/dev/null 2>&1 || {
      __codex_shell_jj_alias_targets_loaded=1
      return 1
    }

    local line command_name aliases alias
    while IFS= read -r line; do
      [[ "$line" == "  "* ]] || continue

      command_name="${${line##[[:space:]]#}%%[[:space:]]*}"
      [[ -n "$command_name" ]] || continue

      if [[ "$line" == *"[default alias: "* ]]; then
        aliases="${line#*"[default alias: "}"
        aliases="${aliases%%\]*}"
        for alias in ${(s:,:)aliases}; do
          alias="${alias//[[:space:]]/}"
          [[ -n "$alias" ]] && __codex_shell_jj_alias_targets[$alias]="$command_name"
        done
      fi

      if [[ "$line" == *"[aliases: "* ]]; then
        aliases="${line#*"[aliases: "}"
        aliases="${aliases%%\]*}"
        for alias in ${(s:,:)aliases}; do
          alias="${alias//[[:space:]]/}"
          [[ -n "$alias" ]] && __codex_shell_jj_alias_targets[$alias]="$command_name"
        done
      fi
    done < <(command jj --color=never --help 2>/dev/null)

    __codex_shell_jj_alias_targets_loaded=1
    (( ${#__codex_shell_jj_alias_targets[@]} > 0 ))
  }

  __codex_shell_resolve_bare_subcommand() {
    emulate -L zsh

    local cmd="$1"
    [[ -n "$cmd" ]] || return 1

    if [[ "$__codex_shell_jj_root_check_pwd" != "$PWD" ]]; then
      __codex_shell_jj_root_check_pwd="$PWD"
      __codex_shell_jj_root_active=0
      command -v jj >/dev/null 2>&1 && jj root --ignore-working-copy >/dev/null 2>&1 && __codex_shell_jj_root_active=1
    fi

    if (( __codex_shell_jj_root_active )); then
      __codex_shell_load_jj_alias_targets >/dev/null 2>&1 || true
      if [[ -n "${__codex_shell_jj_alias_targets[$cmd]-}" ]]; then
        print -r -- "jj ${__codex_shell_jj_alias_targets[$cmd]}"
        return 0
      fi
    fi

    return 1
  }

  __codex_shell_dispatch_bare_subcommand() {
    emulate -L zsh

    local cmd="$1" resolved tool subcommand
    shift || true

    resolved="$(__codex_shell_resolve_bare_subcommand "$cmd")" || return 1
    tool="${resolved%% *}"
    subcommand="${resolved#* }"
    command "$tool" "$subcommand" "$@"
  }

  if (( $+functions[command_not_found_handler] )) && [[ "${__codex_shell_command_not_found_handler_installed:-0}" != "1" ]] && (( ! $+functions[__codex_shell_previous_command_not_found_handler] )); then
    functions -c command_not_found_handler __codex_shell_previous_command_not_found_handler
  fi
  typeset -g __codex_shell_command_not_found_handler_installed=1

  command_not_found_handler() {
    emulate -L zsh

    __codex_shell_dispatch_bare_subcommand "$@" && return $?

    if (( $+functions[__codex_shell_previous_command_not_found_handler] )); then
      __codex_shell_previous_command_not_found_handler "$@"
      return $?
    fi

    print -u2 -- "zsh: command not found: $1"
    return 127
  }

  __codex_shell_line_is_direct_command() {
    emulate -L zsh
    setopt local_options extended_glob

    local line="$*"
    line="${line//$'\r'/$'\n'}"

    [[ -z "${line//[[:space:]]/}" ]] && return 0
    [[ "$line" == *$'\n'* ]] && return 0
    [[ "$line" == [[:space:]]#\#* ]] && return 0

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

    whence -w -- "$cmd" >/dev/null 2>&1 && return 0
    __codex_shell_resolve_bare_subcommand "$cmd" >/dev/null 2>&1 && return 0

    # If a line already looks like a CLI invocation, let zsh handle it. This
    # preserves normal command-not-found behavior for typos and shell aliases
    # that may be loaded outside this router.
    local arg
    for arg in "${words[@]:1}"; do
      case "$arg" in
        --|--?*|-?*)
          return 0
          ;;
      esac
    done

    if [[ "$line" == *[./~=\|';'\"\`\$\<\>\&\(\)\[\]\{\}]* ]]; then
      return 0
    fi

    return 1
  }

  __codex_shell_should_proxy_line() {
    emulate -L zsh

    [[ "${CODEX_SHELL_ENTER:-0}" == "1" ]] || return 1
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

  if [[ "${CODEX_SHELL_ENTER:-0}" == "1" ]]; then
    zle -N accept-line __codex_shell_accept_line
  else
    zle -A .accept-line accept-line 2>/dev/null || true
  fi
fi
