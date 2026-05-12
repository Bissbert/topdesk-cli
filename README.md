# topdesk-cli

![GitHub last commit](https://img.shields.io/github/last-commit/Bissbert/topdesk-cli)

> Pure-shell TOPdesk REST API client — automate incident management, person/operator/asset CRUD, and ITSM workflows without installing a runtime.

## Why

TOPdesk's REST API is capable but typically accessed through bespoke scripts or full programming language SDKs. topdesk-cli is a POSIX sh dispatcher that wraps the API in composable subcommands, making it scriptable from any Unix shell without Python, Node, or any language runtime beyond `curl` and optionally `jq`. It fits naturally into cron jobs, CI pipelines, and maintenance scripts that already live in shell.

## Quick start

```bash
# Install (user-local, no root)
make

# System-wide
sudo make install PREFIX=/usr/local

# First-time setup
topdesk config init
# Edit ~/.config/topdesk/config and set TDX_BASE_URL and auth vars

# Verify connectivity
topdesk ping
topdesk doctor

# List recent incidents
topdesk incidents --limit 10 --format tsv --headers

# Create an incident from a JSON payload
topdesk incidents-create --data @incident.json

# Export all persons to CSV
topdesk persons --all --fields id,networkLoginName,firstName,lastName --format csv --headers
```

## How it works

- `bin/topdesk` — POSIX sh dispatcher backed by `lib/common.sh`, `lib/config.sh`, `lib/args.sh`, and `lib/log.sh`. Discovers subcommands in `tools/` and routes to them.
- `tools/call` — low-level HTTP caller with auth handling, retries, dry-run, and TLS options. All higher-level subcommands delegate to it.
- `tools/incidents*` — list, get, create, update, add-note, upload/download attachments.
- `tools/persons*`, `tools/operators*`, `tools/assets*` — full CRUD with pagination (`--all`, `--limit`, `--page-size`) and flexible output formats.
- `tools/ping` / `tools/doctor` — connectivity check and comprehensive dependency/config health check with optional `--fix`.
- `lib/paginate.sh` — automatic pagination through TOPdesk result sets.
- `tests/` — TAP test suite with a mocked curl shim; no real network traffic required.

## Configuration

Config file at `~/.config/topdesk/config` (XDG) or a path passed with `--config`. Managed via `topdesk config`.

| Variable | Description |
|---|---|
| `TDX_BASE_URL` | TOPdesk base URL, e.g. `https://topdesk.example.com` |
| `TDX_AUTH_TOKEN` | Full Authorization header value (`Bearer …` or `Basic …`) |
| `TDX_AUTH_HEADER` | Raw custom header string (overrides token/basic auth) |
| `TDX_USER` / `TDX_PASS` | Basic auth fallback |
| `TDX_VERIFY_TLS` | `1` (default) or `0` to skip TLS verification |
| `TDX_TIMEOUT` | Request timeout in seconds (default `30`) |
| `TDX_PAGE_SIZE` | Default page size for paginated calls (default `100`) |

## Status

Actively maintained.

## License

MIT
