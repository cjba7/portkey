# Integrations

## Docker Compose

Reference portkey variables in `docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
  redis:
    image: redis:7
    ports:
      - "${REDIS_PORT:-6379}:6379"
```

Or pass them via `portkey show`:

```bash
docker run --env-file <(portkey show myapp) myimage
```

## Rails

### database.yml

```yaml
development:
  adapter: postgresql
  host: localhost
  port: <%= ENV.fetch("POSTGRES_PORT", 5432) %>
  database: myapp_development
```

### config/redis.yml

```yaml
development:
  url: redis://localhost:<%= ENV.fetch("REDIS_PORT", 6379) %>/0
```

### Puma

```ruby
# config/puma.rb
port ENV.fetch("APP_PORT", 3000)
```

## direnv

In `envrc` mode, portkey writes directly to `.envrc` and runs `direnv allow`. Variables are available automatically when you `cd` into the project.

If direnv isn't installed, portkey writes the file but prints a warning. You can source it manually:

```bash
eval "$(portkey show myapp --export)"
```

## dotenv

In `dotenv` mode, portkey writes `.env` with `KEY=VALUE` lines compatible with:

- [dotenv](https://github.com/bkeepers/dotenv) (Ruby)
- [python-dotenv](https://github.com/theskumar/python-dotenv)
- [godotenv](https://github.com/joho/godotenv) (Go)
- Docker `--env-file`

## iTerm2 tab colours & Claude Code status badge

portkey can colour each project's terminal so you always know which one you're
in. Every project gets a `colour` (auto-assigned by `portkey add`, see
[Configuration → Colours](configuration.md#colours)). Two things consume it:

- the **iTerm2 tab** is tinted on every `cd` (a zsh/bash hook), and
- the **Claude Code status line** shows a matching colour badge.

Both look the colour up the same way — `portkey resolve` finds the project
whose path is the longest prefix of the current directory — so the tab and the
badge always agree. The colour lives only in `~/.portkey.yml`; there is no
separate rules file to keep in sync.

### One-command setup

```bash
portkey setup
```

This wires up both pieces, idempotently and with backups:

- adds `eval "$(portkey shell-init zsh)"` to your `~/.zshrc` (or `~/.bashrc`),
  inside a `# >>> portkey >>>` … `# <<< portkey <<<` block, and
- points Claude Code's `statusLine` at `portkey statusline` in
  `~/.claude/settings.json` (other keys are preserved).

Restart your shell afterwards. The tab tint is iTerm2-specific (the hook is a
no-op in other terminals); the status badge works in any terminal.

### Manual wiring

If you'd rather wire it up yourself, the building blocks are plain commands:

```bash
# ~/.zshrc — tint the tab on every cd
eval "$(portkey shell-init zsh)"   # or: portkey shell-init bash
```

```json
// ~/.claude/settings.json — coloured badge + dir + model + context%
"statusLine": { "type": "command", "command": "portkey statusline" }
```

`portkey statusline` reads Claude Code's session JSON on stdin and renders the
badge in Ruby — no `jq` or helper script required. `portkey resolve [dir]`
prints `R G B label` for a directory (or nothing), and is what the shell hook
calls under the hood.
