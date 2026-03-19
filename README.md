# portkey

A system-wide port registry for developers running multiple projects concurrently. portkey assigns stable, non-conflicting port numbers per project and writes them as environment variables into `.env` or `.envrc` files.

## Installation

```bash
brew tap cjba7/portkey && brew install portkey
```

Or from source: `git clone https://github.com/cjba7/portkey.git && cd portkey && ruby -Ilib bin/portkey --help`

## Quick start

```bash
portkey init                        # create ~/.portkey.yml
cd ~/code/myapp && portkey add myapp  # register project, auto-assign ports
portkey list                        # see all projects and ports
```

After `portkey add`, your project directory has a `.env` (or `.envrc`) with:

```
APP_PORT=3000
POSTGRES_PORT=5432
REDIS_PORT=6379
```

Each new project gets ports incremented by 10, so they never conflict.

## Commands

```
portkey init                  Create ~/.portkey.yml (prompts for output mode)
portkey add <name>            Register current directory with auto-assigned ports
portkey add <name> --services app,postgres,redis,sidekiq
                              Register with specific services
portkey remove <name>         Remove a project
portkey list                  List all projects and ports
portkey show <name>           Print env vars for a project (pipeable)
portkey show <name> --export  Print with export prefix for shell eval
portkey apply <name>          Write env file(s) into the project directory
portkey apply --all           Write env file(s) for all projects
portkey status                Show which ports are in use vs free
portkey check                 Scan for port conflicts
portkey doctor                Verify config, paths, and env files are in sync
```

## Config

Location: `~/.portkey.yml`

```yaml
mode: dotenv  # default mode: dotenv, envrc, or both

projects:
  myapp:
    path: ~/code/myapp
    app: 3000
    postgres: 5432
    redis: 6379

  frontend:
    path: ~/code/frontend
    mode: envrc  # per-project override
    app: 3010
```

## Documentation

- [Configuration](docs/configuration.md) — modes, per-project overrides, custom services
- [Commands](docs/commands.md) — full command reference with examples
- [Docker & Rails](docs/integrations.md) — using portkey with Docker Compose, Rails, Puma, Redis
- [How it works](docs/how-it-works.md) — port assignment, env file merging, direnv integration

## Contributing

1. Fork the repo
2. Run tests: `ruby -Ilib -Itest -e 'Dir.glob("test/*_test.rb").each { |f| require_relative f }'`
3. Open a pull request

## License

MIT
