# codex-shell-proxy

Natural-language Enter proxy for zsh using Codex.

Valid shell commands still run normally. Lines that are not recognized as direct shell commands are sent to Codex/Spark as terminal requests.

## Install

```sh
./install.zsh
```

Then open a new terminal or run:

```sh
source ~/.zshrc
```

## Try It

Direct shell command:

```sh
ls
```

Natural-language request:

```text
can you ls
```

Obvious shell requests are handled by a local deterministic fast path. For
example, `can you ls` maps directly to `ls` without starting Codex.

For requests that need Codex, the natural-language line stays visible, then the
shell prints:

```text
gpt-5.3-codex-spark is thinking....
```

## Configuration

```sh
export CODEX_SHELL_ENTER=0
```

Disable Enter interception for the current shell.

```sh
export CODEX_SHELL_MODEL=gpt-5.3-codex-spark
export CODEX_SHELL_REASONING=low
```

Choose the Codex model/reasoning pair.

```sh
export CODEX_SHELL_SHOW_COMMANDS=0
```

Hide the `$ /bin/zsh -lc ...` command line and show only command output.

```sh
export CODEX_SHELL_FAST_PATH=0
```

Disable local fast paths and send every natural-language request to Codex.

```sh
export CODEX_SHELL_YOLO=1
```

Use Codex YOLO mode for natural-language requests.

## Test

```sh
bin/test-codex-shell-router
```

The router test runs the deterministic command-vs-natural-language classifier inside an interactive zsh login shell. It does not invoke Codex and does not execute candidate commands.
