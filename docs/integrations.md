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
