# Configuration

portkey stores all configuration in `~/.portkey.yml`.

## Mode

The `mode` setting controls which file(s) `portkey apply` writes:

| Mode | File(s) written | Use case |
|---|---|---|
| `dotenv` | `.env` with `KEY=VALUE` | Default. Works with dotenv gems/libraries |
| `envrc` | `.envrc` with `export KEY=VALUE` | For direnv users |
| `both` | Both `.envrc` and `.env` | Mixed tooling |

Set during `portkey init`, or edit `~/.portkey.yml` directly.

## Per-project mode

Each project can override the root mode:

```yaml
mode: dotenv

projects:
  api:
    path: ~/code/api
    app: 3000
    postgres: 5432

  frontend:
    path: ~/code/frontend
    mode: envrc          # uses .envrc instead of .env
    app: 3010
```

If a project doesn't specify `mode`, it inherits the root setting.

## Custom services

By default, `portkey add` assigns three services: `app`, `postgres`, `redis`. Use `--services` to customise:

```bash
portkey add myapp --services app,postgres,redis,sidekiq,elasticsearch
```

You can also add services manually by editing `~/.portkey.yml`:

```yaml
projects:
  myapp:
    path: ~/code/myapp
    app: 3000
    postgres: 5432
    redis: 6379
    sidekiq: 7433
    elasticsearch: 9200
```

Then run `portkey apply myapp` to write the updated env file.

## Environment variable naming

All services use `UPPERCASED_NAME_PORT`:

- `app` → `APP_PORT`
- `postgres` → `POSTGRES_PORT`
- `redis` → `REDIS_PORT`
- `sidekiq` → `SIDEKIQ_PORT`

## Port assignment

Ports are assigned from base values, incrementing by 10 per project:

| Service | Base port | Project 1 | Project 2 | Project 3 |
|---|---|---|---|---|
| app | 3000 | 3000 | 3010 | 3020 |
| postgres | 5432 | 5432 | 5442 | 5452 |
| redis | 6379 | 6379 | 6389 | 6399 |

Services not in the default list start from port 8000.

The increment of 10 leaves room for services that use multiple consecutive ports.
