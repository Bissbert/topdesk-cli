# Documentation

The write-ups below describe the client as it exists in the source tree. The
measurement scripts live in [`../devtools/`](../devtools/) because `tools/` is
the product's command directory.

| | Component | In one line |
|---|---|---|
| 1 | [API call path](01-api-call.md) | How a resource command builds an authenticated request and returns output. |
| 2 | [Configuration and credentials](02-configuration.md) | Where settings come from, how auth is selected, and what is logged. |
| 3 | [Health checks and errors](03-health-and-errors.md) | The `ping`/`doctor` paths and their exit behavior. |
| — | [Command surface](commands.md) | Every executable in `tools/`, generated from the source files. |
| — | [Measurement](measurement.md) | The Linux container run behind every number. |
| — | [Bugs found](BUGS-FOUND.md) | Seven fixed bugs with their commits. |

[← back to the overview](../README.md)
