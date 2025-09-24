Topdesk Toolkit — TODO

Current status
- Dispatcher `bin/topdesk` loads vendored libs from `lib/` and subcommands from `tools/`
- Implemented commands today: core `call`, incidents (list/get/create/update/add-note/attachments), persons (list/search/get), assets (list/search/get), config list/path, completion scripts
- TAP-style smoke tests live in `tests/run.sh` with a mocked `curl`; quick installs handled by the Makefile (system and per-user)

Bugs to fix
- None currently tracked; keep exercising the suite to catch regressions early

Testing & automation
- Extend the TAP suite to cover additional edge cases (non-JSON responses, HEAD/204 flows, attachment failures)
- Keep expanding CSV/TSV fixtures beyond incidents to cover other list commands

Documentation
- Add cookbook-style docs for create/update/note/attachment workflows with sample payloads
- Document authentication examples (token header vs. basic auth) inline with `topdesk call` usage and clarify pagination expectations (need `jq` for aggregation)
- Describe how to run the test harness and mock environment for contributions
