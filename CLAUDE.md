# portkey

A Ruby CLI tool that manages per-project port assignments via a central `~/.portkey.yml` config file. It writes environment files (`.envrc`, `.env`, or both — configurable via `mode` setting) into project directories so that direnv or dotenv-compatible tools can inject stable, non-conflicting port numbers as environment variables. No external gem dependencies at runtime — plain Ruby and stdlib only.

## File structure

```
lib/portkey.rb           # Module root, version, requires submodules
lib/portkey/config.rb    # Read/write ~/.portkey.yml (YAML parsing, validation)
lib/portkey/registry.rb  # Port auto-assignment logic (base ports + increment by 10)
lib/portkey/envrc_writer.rb  # Generates .envrc/.env content, writes to project dirs
lib/portkey/port_checker.rb  # Checks bound ports via lsof or /proc/net/tcp
lib/portkey/cli.rb       # Command dispatch using OptionParser
bin/portkey              # Executable entry point
test/                    # Minitest test files
```

## Running tests

```
ruby -Ilib -Itest -e 'Dir.glob("test/*_test.rb").each { |f| require_relative f }'
```

Or run a single test file:

```
ruby -Ilib -Itest test/config_test.rb
```

## Testing the CLI locally

```
ruby -Ilib bin/portkey <command>
```

Examples:

```
ruby -Ilib bin/portkey init
ruby -Ilib bin/portkey add myapp
ruby -Ilib bin/portkey list
ruby -Ilib bin/portkey status
ruby -Ilib bin/portkey apply --all
ruby -Ilib bin/portkey check
ruby -Ilib bin/portkey remove myapp
```

## Key design decisions

- **No external gem dependencies** in runtime code — only Ruby stdlib (`yaml`, `optparse`, `open3`, `set`, `fileutils`)
- **Configurable output mode** (`envrc`, `dotenv`, or `both`) — set during `portkey init`, stored in `~/.portkey.yml` as the `mode` key
- **`direnv` is a system dependency** for `envrc`/`both` modes, not managed by portkey. If direnv is not installed, `portkey apply` still writes the file(s) but prints a warning instead of running `direnv allow`
- **Port blocks increment by 10** to leave room for future services per project
- **Env files are owned by portkey** — it will overwrite them on `apply`. Do not manually edit `.envrc`/`.env` files in project directories; edit `~/.portkey.yml` instead
- **Dependency injection** in constructors (`config_path:`, `port_checker:`, `stdout:`, `stdin:`) for test isolation — tests never touch the real `~/.portkey.yml`
- **Only `postgres` is special-cased** to `DB_PORT`. All other services use `NAME_PORT` (uppercased)
- **Key deduplication** — each env var key appears only once per file; if two services map to the same key, the first wins

## Do not

- Run `bundle install` or `gem install` for anything beyond dev/test tooling
- Add external gem dependencies to `lib/` or `bin/`
