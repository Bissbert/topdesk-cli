# topdesk-cli

![GitHub last commit](https://img.shields.io/github/last-commit/Bissbert/topdesk-cli)

> Pure-shell TOPdesk REST API client — automate incident management, person/operator/asset CRUD, and ITSM workflows without installing a runtime.

Topdesk Toolkit is a portable POSIX `sh` command line client for common Topdesk
REST operations. The `bin/topdesk` dispatcher loads configuration, selects a
tool from `tools/`, and leaves HTTP transport to `curl`; the result is ordinary
stdout/stderr that can be composed with other shell commands.

```mermaid
flowchart LR
    U["shell user"] --> D["bin/topdesk<br/>dispatcher"]
    D --> T["tools/<br/>subcommand"]
    T --> L["lib/<br/>shared helpers"]
    L --> X["curl"]
    X --> A["Topdesk REST API"]
    T --> O["stdout / stderr"]

    style D fill:#1f6feb,stroke:#58a6ff,color:#fff
    style A fill:#238636,stroke:#3fb950,color:#fff
    style O fill:#8250df,stroke:#bc8cff,color:#fff
```

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

### Inspect without a tenant

These local commands were run from the repository checkout and do not contact a
Topdesk tenant:

```sh
./bin/topdesk --version
./bin/topdesk help
./bin/topdesk config --help
./bin/topdesk doctor --help
```

These four commands exit 0 in a Linux container. The API commands need a real
tenant and credentials; they are covered only by the test suite's curl shim.

## How it works

- `bin/topdesk` — POSIX sh dispatcher backed by `lib/common.sh`, `lib/config.sh`, `lib/args.sh`, and `lib/log.sh`. Discovers subcommands in `tools/` and routes to them.
- `tools/call` — low-level HTTP caller with auth handling, retries, dry-run, and TLS options. All higher-level subcommands delegate to it.
- `tools/incidents*` — list, get, create, update, add-note, upload/download attachments.
- `tools/persons*`, `tools/operators*`, `tools/assets*` — full CRUD with pagination (`--all`, `--limit`, `--page-size`) and flexible output formats.
- `tools/ping` / `tools/doctor` — connectivity check and comprehensive dependency/config health check with optional `--fix`.
- `lib/paginate.sh` — automatic pagination through TOPdesk result sets.
- `tests/` — TAP test suite with a mocked curl shim; no real network traffic required.

## Architecture

The dispatcher loads the selected configuration before resolving a command. A
resource wrapper either calls `tools/call` once or uses the pagination helpers
to repeat that call and shape JSON, TSV, or CSV output.

```mermaid
flowchart TD
    S["topdesk command"] --> D["dispatcher<br/>global options + config load"]
    D --> R{"resource or system tool?"}
    R -->|"incidents / persons / operators / assets"| W["resource wrapper"]
    R -->|"config / ping / doctor / completion"| Q["local or diagnostic tool"]
    W --> P{"--all or --limit?"}
    P -->|yes| PG["pagination helpers<br/>page size + offset"]
    P -->|no| C["tools/call"]
    PG --> C
    C --> H["select auth<br/>header, token, or basic"]
    H --> X["curl request"]
    X --> API["Topdesk REST API"]
    API --> C
    C --> OUT["raw / pretty / tabular output"]
    Q --> OUT

    style D fill:#1f6feb,stroke:#58a6ff,color:#fff
    style H fill:#9e6a03,stroke:#d29922,color:#fff
    style API fill:#238636,stroke:#3fb950,color:#fff
    style OUT fill:#8250df,stroke:#bc8cff,color:#fff
```

## Capability overview

| Area | Entry points | What it does |
|---|---|---|
| HTTP | `call` | Builds a `curl` request with query, body, headers, TLS, retries, and output controls. |
| Incidents | `incidents` and `incidents-*` | Lists, reads, creates, updates, annotates, uploads, and downloads incident data. |
| People and operators | `persons*`, `operators*` | Lists, searches, reads, creates, and updates records. |
| Assets | `assets*` | Lists, searches, reads, creates, and updates assets. |
| Output | list tools | Emits JSON, or jq-shaped TSV/CSV with optional headers. |
| Configuration | `config` | Finds, initializes, edits, lists, validates, and reports the active config file. |
| Health | `ping`, `doctor` | Separates API connectivity/authentication checks from local diagnostics. |
| Shell integration | `completion` | Prints Bash or Zsh completion code. |

The complete source-derived table of executable tools is in
[`docs/commands.md`](docs/commands.md).

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

## Results

All results come from `devtools/linux-run.sh`, run in a
`python:3.12-slim-bookworm` container (`/bin/sh` is dash):

| Measurement | Result |
|---|---:|
| shell files under `bin/`, `lib/`, and `tools/` | 35 |
| shell source lines | 3,538 |
| shell source bytes | 101,122 |
| executable tools | 27 |
| `make test` | 82 passed, 0 failed |

`doctor` runs all its sections and prints a summary in the default, `--quiet`
and `--verbose` modes, counts all 27 tools as executable, and runs with `SHELL`
unset. Bugs are tracked as
[GitHub issues](https://github.com/Bissbert/topdesk-cli/issues).

See [`docs/measurement.md`](docs/measurement.md) for the commands and the full
output.

## Tests

```sh
make test          # all test files, TAP output and a summary line
sh tests/docker.sh # the same in a Debian container
```

The suite puts a mock `curl` and `editor` from `tests/bin` first on `PATH`, so
no tenant is contacted. Each test file runs in its own temporary `HOME`, so
your `~/.config/topdesk/config` is neither read nor changed.

| File | Covers |
|---|---|
| `tests/run.sh` | dispatcher, `call`, listing, pagination, formats, CRUD, config, completion |
| `tests/commands.sh` | the other commands: request method, path, payload, auth variants, exit codes |
| `tests/doctor.sh` | every `doctor` section, `--quiet`, `--fix`, `SHELL` unset |
| `tests/isolation.sh` | suite isolation from the user config, failing checks fail the run |

## Repository layout

```text
bin/topdesk       dispatcher and global option handling
lib/              configuration, logging, arguments, JSON, and pagination
tools/            executable command implementations
devtools/         source-shape and command-surface measurement scripts
share/examples/   configuration template
tests/            test files, mock curl/editor, Docker runner
docs/             command table, subsystem write-ups, and measurement notes
```

## Known limitations

- No real Topdesk tenant or credentials were available, so API responses,
  authentication, uploads, downloads, and latency are not covered.
- `curl` is required. `jq` is optional for JSON formatting and required for
  tabular output and pagination helpers.
- Configuration files are shell files sourced by the client. They are plain
  text, not encrypted storage; `doctor` can warn about world-readable files.
- `call --dry-run` prints the constructed curl command, including authentication
  arguments when configured. Do not paste that output into shared logs.
- `--insecure` and `TDX_VERIFY_TLS=0` disable TLS certificate verification.
- Asset-template management is not exposed by the command surface; it remains
  outside this client.

## Status

Actively maintained.

## License

MIT
