[← back to the overview](../README.md)

# How this was measured

Every number in this documentation comes from one script run in a Linux
container:

```sh
sh devtools/linux-run.sh > docs/captures/linux-run.txt
```

[`devtools/linux-run.sh`](../devtools/linux-run.sh) starts
`python:3.12-slim-bookworm`, installs bash, curl, jq, make and git, mounts the
repository read-only and copies it. No Topdesk tenant is contacted: the test
suite uses the curl shim in `tests/bin`, and the `doctor` runs use an empty
temporary config location. The full output is
[`captures/linux-run.txt`](captures/linux-run.txt); every block below is taken
from it.

```mermaid
flowchart LR
    S["repository copy"] --> R["repo-stats.sh"]
    S --> C["command-surface.sh"]
    S --> T["make test"]
    S --> D["doctor runs"]
    R --> N["README results"]
    C --> M["docs/commands.md"]
    T --> B["test and doctor results"]
    D --> B

    style S fill:#1f6feb,stroke:#58a6ff,color:#fff
    style N fill:#238636,stroke:#3fb950,color:#fff
    style M fill:#238636,stroke:#3fb950,color:#fff
    style B fill:#8250df,stroke:#bc8cff,color:#fff
```

## Environment

| | |
|---|---|
| Kernel | Linux 6.5.11-linuxkit, aarch64 (Docker Desktop VM) |
| Image | `python:3.12-slim-bookworm` (`sha256:392307d2…23564e`) |
| Tools | GNU bash 5.2.15, curl 7.88.1, jq 1.6; `/bin/sh` is dash |
| Date | 2026-09-24 |

## Source shape

`devtools/repo-stats.sh` counts the shell files under `bin/`, `lib/` and
`tools/`, and the executable product tools:

```
shell files            35
shell lines            3538
shell bytes            101122
subcommands            27
version                0.1.0
```

`sh -n` reports no syntax errors in any of the 35 files under dash.

## Command table

`devtools/command-surface.sh` scans each executable in `tools/` and prints the
table in [`commands.md`](commands.md). Its output is identical to
that file (35 lines).

## Local commands

These run from the checkout and need no tenant:

```
topdesk --version  exit=0
topdesk help  exit=0
topdesk config --help  exit=0
topdesk doctor --help  exit=0
```

## Test suite

`make test` runs the four test files through `tests/all.sh`. With a fresh
`HOME`:

```
# run.sh
1..33
# commands.sh
1..33
# doctor.sh
1..10
# isolation.sh
1..6
Summary: 82 passed, 0 failed
exit=0
```

The run leaves no files in `HOME`. A second run in the same `HOME`, and a run
with an existing `~/.config/topdesk/config` pointing at another tenant, both
give the same summary, and that config file is unchanged
([#5](https://github.com/Bissbert/topdesk-cli/issues/5)).

With one check deliberately broken in a copy of `tests/run.sh`, the runner
reports only that check and exits 1, so TAP failures reach the exit status.

## `doctor`

With an empty config location, the default run prints all seven sections and
the summary:

```
Summary
Checks passed: 4
Warnings: 2
Checks failed: 3
```

`--quiet` prints the three failed checks and the two counts (5 lines).
`--verbose` adds 16 info lines. The permission section reports
`All 27 tools have executable permissions` ([#6](https://github.com/Bissbert/topdesk-cli/issues/6)). With `SHELL` unset the
run prints `Shell: unknown` and reaches the summary, exiting 1 for the failed
configuration checks ([#7](https://github.com/Bissbert/topdesk-cli/issues/7)).

## Not covered

No Topdesk hostname, tenant, credential, incident, attachment, response body,
server latency or network throughput was available. No API operation was run
against a live service; the API tests use the curl shim. The Mermaid diagrams
describe the source; they are not captured program output.
