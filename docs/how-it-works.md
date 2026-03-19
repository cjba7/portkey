# How it works

## Port assignment

When you run `portkey add <name>`, portkey:

1. Reads all existing port assignments from `~/.portkey.yml`
2. For each service, starts at the base port and increments by 10 until it finds a port that is:
   - Not assigned to another project
   - Not currently bound on the system (checked via `lsof` or `/proc/net/tcp`)
3. Writes the new project entry to `~/.portkey.yml`
4. Runs `portkey apply <name>` to write the env file(s)

Default base ports: `app=3000`, `postgres=5432`, `redis=6379`. Unknown services start at `8000`.

## Env file merging

portkey never wipes your env files. When writing:

1. It reads the existing file line by line
2. For each portkey-managed key (e.g. `APP_PORT`), it replaces the existing line in place
3. New keys that don't exist yet are appended at the end
4. All other lines are left untouched

This means your custom variables, comments, and other tool output are preserved.

## Port checking

portkey uses `lsof -iTCP -sTCP:LISTEN -P -n` on macOS to detect bound ports. On Linux, it falls back to parsing `/proc/net/tcp`.

This is used by:
- `portkey add` — to avoid assigning ports that are currently in use
- `portkey status` — to show which ports are in use vs free
- `portkey check` — to detect conflicts with running services
