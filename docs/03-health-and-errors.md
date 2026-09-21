[← back to the overview](../README.md)

# Health checks and errors

`ping` answers a narrow question—can the configured endpoint be reached with
the configured authentication? `doctor` combines local dependency,
configuration, permission, path, and optional network checks. The low-level
caller exposes transport and HTTP failures separately.

```mermaid
flowchart TD
    S["command"] --> A{"arguments valid?"}
    A -->|no| E2["usage error<br/>exit 2"]
    A -->|yes| K{"command path"}
    K -->|"call"| C["curl request"]
    K -->|"ping"| P["endpoint request"]
    K -->|"doctor"| D["local checks"]
    C --> N{"curl status"}
    N -->|"transport failure"| E3["diagnostic<br/>exit 3"]
    N -->|"2xx response"| OK["body / status<br/>exit 0"]
    N -->|"4xx response"| E4["HTTP diagnostic<br/>exit 4"]
    N -->|"5xx response"| E5["HTTP diagnostic<br/>exit 5"]
    N -->|"other response"| E6["HTTP diagnostic<br/>exit 6"]
    P --> PR{"ping result"}
    PR -->|"reachable or endpoint 404"| OKP["status output<br/>exit 0"]
    PR -->|"auth failure"| EA["auth output<br/>exit 2"]
    PR -->|"network or server failure"| EN["status output<br/>exit 1"]
    PR -->|"config or parse failure"| EP["diagnostic<br/>exit 3"]
    D --> DR{"failed checks?"}
    DR -->|no| D0["summary<br/>exit 0"]
    DR -->|yes| D1["summary<br/>exit 1"]

    style OK fill:#238636,stroke:#3fb950,color:#fff
    style OKP fill:#238636,stroke:#3fb950,color:#fff
    style E2 fill:#9e6a03,stroke:#d29922,color:#fff
    style E3 fill:#da3633,stroke:#f85149,color:#fff
    style E4 fill:#da3633,stroke:#f85149,color:#fff
    style E5 fill:#da3633,stroke:#f85149,color:#fff
    style E6 fill:#da3633,stroke:#f85149,color:#fff
```

## `call` failure mapping

The `tools/call` script maps curl and HTTP outcomes as follows:

| Condition | Exit | Output channel |
|---|---:|---|
| Missing method, path, required option, or base URL | 2 | Usage/error on stderr. |
| Curl transport failure, including timeout | 3 | Error on stderr; a short response preview may follow. |
| Successful `2xx` response | 0 | Response body on stdout unless written elsewhere. |
| HTTP `4xx` response | 4 | Status and response preview on stderr. |
| HTTP `5xx` response | 5 | Status and response preview on stderr. |
| Other HTTP status or missing status | 6 or 3 | Diagnostic on stderr. |

The caller removes its temporary body and header files on exit. A response sent
to `--output` is written directly to the requested path; `--tee` keeps stdout
and writes a second copy.

## `ping` and `doctor`

`ping` treats API reachability, authentication, and response parsing as
separate outcomes. It can accept a custom endpoint, and verbose mode prints
request and response diagnostics with auth masking. It cannot make an invalid
tenant or missing credential usable.

`doctor` reports missing dependencies, config problems, TLS settings, and tool
permissions. `--fix` can create a config template or adjust tool permissions,
so it is not a read-only diagnostic option.

The current `doctor` source has two control-flow bugs documented in
[`BUGS-FOUND.md`](BUGS-FOUND.md): the default run can stop after its first
suppressed `check_info`, and `--quiet` can stop at its first suppressed
`section`. Those are the observed current behaviors, not claims about an
intended future implementation.

## Known limitations

- The doctor bugs above prevent a complete diagnostic summary on the current
  source until the recorded fixes are applied.
- The test suite's curl and editor shims are not executable, and the TAP runner
  does not propagate its `not ok` count into the process status. The measured
  test result is therefore not a reliable pass/fail exit signal.
- API status behavior was not exercised against a real tenant for this pass.
- A diagnostic body preview can carry sensitive server data into stderr logs.
