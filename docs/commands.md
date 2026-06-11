# Commands

## portkey init

Create `~/.portkey.yml` with a mode prompt:

```bash
$ portkey init
Select output mode:
  1. dotenv — write .env files (default)
  2. envrc  — write .envrc files for direnv
  3. both   — write both .envrc and .env files
Choice [1]:
Created ~/.portkey.yml (mode: dotenv)
```

## portkey add

Register the current directory as a project:

```bash
cd ~/code/myapp
portkey add myapp
```

With custom services:

```bash
portkey add myapp --services app,postgres,redis,sidekiq
```

With an explicit colour (otherwise one is auto-assigned):

```bash
portkey add myapp --colour "#4f46e5"
```

This auto-assigns ports, picks a tab colour, writes to `~/.portkey.yml`, and
runs `portkey apply`.

## portkey remove

```bash
portkey remove myapp
```

Removes the project from the config. Does not delete env files.

## portkey list

```bash
$ portkey list
myapp
  app          3000
  postgres     5432
  redis        6379
  path         ~/code/myapp
  mode         dotenv
  colour       #4f46e5
```

## portkey show

Print env vars for a project without writing files:

```bash
# dotenv format (default) — pipeable to docker
$ portkey show myapp
APP_PORT=3000
POSTGRES_PORT=5432
REDIS_PORT=6379

# shell format
$ portkey show myapp --export
export APP_PORT=3000
export POSTGRES_PORT=5432
export REDIS_PORT=6379
```

Useful for:

```bash
# Pass to docker run
docker run --env-file <(portkey show myapp) myimage

# Source into current shell
eval "$(portkey show myapp --export)"
```

## portkey apply

Write env file(s) for a single project or all projects:

```bash
portkey apply myapp
portkey apply --all
```

Respects the mode setting (root or per-project). Existing content in the file is preserved — portkey only updates its own keys.

## portkey status

Show which ports are in use vs free:

```bash
$ portkey status
myapp
  app          3000     free
  postgres     5432     in use
  redis        6379     free
```

## portkey check

Scan for conflicts — between projects or with currently bound ports:

```bash
$ portkey check
No port conflicts found.
```

## portkey setup

Wire the tab-colour shell hook and the Claude Code status line into your
environment, idempotently and with backups:

```bash
$ portkey setup
Added portkey block to /Users/you/.zshrc
Set Claude Code statusLine in /Users/you/.claude/settings.json

Done. Restart your shell (or `source` your rc) to start colouring tabs.
```

Detects your shell from `$SHELL`; pass `zsh` or `bash` to override. See
[Integrations → tab colours](integrations.md#iterm2-tab-colours--claude-code-status-badge).

## portkey colours

List project colours, show one, or set one:

```bash
# list every project's colour
$ portkey colours
  myapp            #4f46e5
  frontend         #10b981

# show a project's colour
$ portkey colours myapp
myapp: #4f46e5

# set a project's colour (hex or "R G B")
$ portkey colours myapp "#ef4444"
Set myapp colour to #ef4444
```

## portkey resolve / statusline / shell-init

Plumbing used by the shell integration — you normally won't call these
directly:

```bash
# colour for a directory (default: cwd), as "R G B label", or nothing
$ portkey resolve ~/code/myapp
79 70 229 myapp

# render the Claude Code status line (reads session JSON on stdin)
$ portkey statusline

# print the tab-colour hook for your shell
$ portkey shell-init zsh
```

## portkey doctor

Verify everything is in sync:

```bash
$ portkey doctor
All good. 3 projects checked.
```

Checks:
- Config file exists
- All project directories exist
- Env files are up to date with config
- direnv is installed (if using envrc mode)
