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

This auto-assigns ports, writes to `~/.portkey.yml`, and runs `portkey apply`.

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
