Topdesk Toolkit (topdesk) — Shell toolsuite

Overview

- Minimal, portable POSIX sh toolsuite built on the `toolbox.sh` framework.
- Dispatcher `topdesk` with subcommands in `tools/`.
- Focus: convenient access to the Topdesk REST API for common tasks.

Quick Start

1. First-time setup: `topdesk config init` (create configuration)
2. Verify setup: `topdesk doctor` (check everything is working)
3. Test connection: `topdesk ping` (verify API connectivity)
4. List commands: `topdesk help` (show available commands)
5. Start using: `topdesk incidents --limit 5` (list recent incidents)

Install

Using Makefile (recommended):
- User install: `make install-user` (installs to ~/.local)
- System install: `sudo make install PREFIX=/usr/local`
- Development: `make install-dev` (symlinks for development)
- Uninstall: `make uninstall-user` or `make uninstall`

Dependencies:
- Required: `curl` (for API calls)
- Optional: `jq` (for JSON formatting and CSV/TSV output)

Configuration

Set environment variables or place a config file at `$XDG_CONFIG_HOME/topdesk/config` (defaults to `~/.config/topdesk/config`). Example:

```
# Required
TDX_BASE_URL="https://topdesk.example.com"

# Auth options (choose one)
# 1) Token (recommended)
# Full Authorization header value is supplied via TDX_AUTH_TOKEN.
# Example: "Bearer eyJ..." or "Basic Zm9vOmJhcg==" (as required by your setup)
TDX_AUTH_TOKEN="Bearer <full-token>"

# 2) Custom header (advanced)
# If you need a non-Authorization header or multiple headers
# TDX_AUTH_HEADER="Authorization: Bearer <token>"

# 3) Basic auth (fallback)
TDX_USER="apiuser"
TDX_PASS="apipass"

# TLS and network
TDX_VERIFY_TLS=1         # 0 to skip verification (curl -k)
TDX_TIMEOUT=30           # seconds
TDX_RETRY=0              # curl retry count
TDX_RETRY_DELAY=0        # seconds between retries

# Pagination defaults (override if your instance uses different names)
TDX_PAGE_SIZE=100
TDX_PAGE_PARAM=pageSize
TDX_OFFSET_PARAM=start
TDX_OFFSET_START=0

# Optional defaults for list outputs
#TDX_DEFAULT_FIELDS=number,id,briefDescription
#TDX_PERSON_FIELDS=id,networkLoginName,firstName,lastName
#TDX_OPERATOR_FIELDS=id,name,networkLoginName
#TDX_ASSET_FIELDS=id,objectNumber,name
```

Notes on authentication

- If `TDX_AUTH_HEADER` is set, it is passed through to curl (`-H`).
- Otherwise, if `TDX_USER` and `TDX_PASS` are set, Basic auth is used via curl `-u user:pass`.
- This avoids guessing a specific Topdesk token scheme; set `TDX_AUTH_HEADER` when using API tokens.

Commands (initial)

- `topdesk call` — low-level HTTP caller to Topdesk API with headers/auth handling (reports HTTP errors with informative exit codes and accepts repeatable `--param KEY=VAL`). Notable flags: `--pretty`, `--raw`, `--retry`, `--insecure`, TLS CA overrides, and workflow helpers like `--dry-run`, `--output FILE`, and `--tee FILE`.
- `topdesk incidents` — list incidents; supports `--format {tsv|csv|json}`, `--headers`, repeatable `--param KEY=VAL`, the `--archived BOOL` filter, `--raw`, `--pretty`, `--all`, `--limit`, and custom pagination knobs.
  - Pagination: `--all`, `--limit N`, `--page-size`, `--page-param`, `--offset-param`.
- `topdesk incidents-get` — get incident by `--id` or `--number`; combine with `--all` to return every match for a number instead of the first hit.
- `topdesk incidents-create` — create incident from JSON payload.
- `topdesk incidents-update` — update incident by id (PATCH default, or PUT with `--method`).
- `topdesk incidents-add-note` — add a note to an incident (override path if your API differs).
- `topdesk incidents-attachments-upload` — upload attachment to an incident (multipart). Supports `--name`, `--timeout SEC`, and `--insecure` to skip TLS verification.
- `topdesk incidents-attachments-download` — download an attachment from an incident. Supports `--output FILE`, `--timeout SEC`, and `--insecure`.
- `topdesk persons` — list persons; `--format`, `--headers`, `--fields`, `--path`, `--query`, and repeatable `--param KEY=VAL` supported.
  - Pagination: `--all`, `--limit N`, `--page-size`, `--page-param`, `--offset-param`.
- `topdesk persons-get` — get person by id.
- `topdesk persons-search` — list persons using an arbitrary query string (or repeatable `--param KEY=VAL`).
- `topdesk persons-create` — create a person from JSON payload (`--path` override available).
- `topdesk persons-update` — update a person by id via PATCH (default) or PUT; supports `--method` and `--path` overrides.
- `topdesk operators` — list operators (`--format`, pagination, filtering, `--param KEY=VAL`).
- `topdesk operators-get` — get operator by id.
- `topdesk operators-search` — list operators using an arbitrary query string (or repeatable `--param KEY=VAL`).
- `topdesk operators-create` — create an operator from JSON payload (`--path` override available).
- `topdesk operators-update` — update an operator by id via PATCH (default) or PUT.
- `topdesk assets` — list assets; `--format`, `--headers`, `--fields`, `--path`, `--query`, and repeatable `--param KEY=VAL` supported.
  - Pagination: `--all`, `--limit N`, `--page-size`, `--page-param`, `--offset-param`.
- `topdesk assets-get` — get asset by id.
- `topdesk assets-search` — list assets using an arbitrary query string (or repeatable `--param KEY=VAL`).
- `topdesk assets-create` — create an asset from JSON payload (`--path` override available).
- `topdesk assets-update` — update an asset by id via PATCH (default) or PUT.
- `topdesk ping` — test connectivity and authentication to Topdesk API. Supports `--verbose`, `--quiet`, `--timeout SEC`, and `--endpoint PATH` for custom endpoints.
- `topdesk doctor` — comprehensive health check and diagnostics. Checks dependencies, configuration, authentication, network connectivity, and permissions. Supports `--verbose`, `--quiet`, and `--fix` to attempt automatic fixes.
- `topdesk config` — manage config files (`list`, `path`, `init`, `edit`, `validate`).
- `topdesk completion` — shell completion (bash/zsh) inherited from framework.

Examples

Configuration and health checks:
- `topdesk config init` — create a configuration template
- `topdesk config list` — show current configuration (with sensitive values redacted)
- `EDITOR="code --wait" topdesk config edit` — edit configuration in VS Code
- `topdesk ping` — quick connectivity test
- `topdesk ping -v` — verbose connectivity test with details
- `topdesk doctor` — comprehensive health check
- `topdesk doctor --fix` — health check with automatic fixes

API operations:
- `topdesk call GET /tas/api/incidents --param pageSize 50 --param archived false --pretty`
- `topdesk incidents --page-size 200 --format tsv --headers`
- `topdesk incidents --all --format csv --headers`
- `topdesk persons --all --fields id,networkLoginName,firstName,lastName --format tsv --headers`
- `topdesk operators --fields id,name,networkLoginName --format csv`
- `topdesk persons-create --data @person.json`
- `topdesk assets-update --id a1 --data '{"status":"In repair"}'`

Testing

- `make test` runs the TAP suite (uses the mocked curl shim; no real network traffic).
- `make check` runs shellcheck plus `shfmt -d` when available.
- `make fmt` formats all shell scripts with shfmt (if installed).

Limitations

- Asset template ("asset type") CRUD is not exposed by the Topdesk REST API; templates must still be managed through the web UI or import tools.
