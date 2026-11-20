---
name: nk-audit-output
description: Run the project's nullkomma tasks and services and fix the causes of warnings, noise and other suspicious output, without ever filtering output.
---

# Auditing task output

Find output that a clean run should not print, then remove its cause.

## Run everything

Use the `nullkomma` MCP server from `.mcp.json`;
without it, run `nk <task>` in the dev shell and read its output.

1. Call every task tool, one at a time, so each output belongs to one task.
   Skip tasks that change remote state, credentials or `flake.lock`
   (read the descriptions, e.g. `deploy`, `flake-update`),
   unless the user asks for them.
   Run `flake-check` last; it takes longest.
1. Start each service with `pc_process_start`.
   Wait until `pc_process_get` reports it ready,
   read `pc_process_logs`, then stop it with `pc_process_stop`.

## Review the output

Look for anything a reader would stop at, even when the task succeeded:

- warnings, deprecations, notes and hints;
- errors that do not fail the task, retries and timeouts;
- debug output, progress bars and repeated lines in logs;
- version mismatches, missing optional tools, fallbacks.

## Fix the cause, never the output

For each finding, find what prints it and why.
Two fixes are acceptable:

1. Remove the cause: change the code, configuration, data or versions
   so that the tool has nothing to report.
1. Switch the output off with an option the tool documents
   (a log level, a quiet flag, a setting),
   and only for output that tells the user nothing they need.
   Never switch off a warning about a real problem; fix the problem.

Never filter output:
no `grep -v`, `sed`, `2>/dev/null`, discarded streams or log-processing rules.
If neither fix is clean, leave the output as it is.

If the cause is in nullkomma (its generated files or its `/nix/store` paths),
or in another upstream project, do not patch around it:
report it to that project, unless an issue for it already exists.

Rerun the affected task to confirm each fix.
Then report every finding with its cause and what you did,
including the ones you left or reported upstream.
