# Stopping R's subprocesses

Background for `r-contain` and the `shutdown.signal = 2` of the R tasks.
Read this before you change how R tasks are started or stopped.

## Problem

R packages start subprocesses through [processx](https://processx.r-lib.org):

- testthat starts one `callr::r_session` per worker
  when `DESCRIPTION` has `Config/testthat/parallel: true`
  (`R/parallel-taskq.R` in testthat 3.3.2);
- rcmdcheck starts `R CMD build` (`pkgbuild_process`) and `R CMD check` (`callr::rcmd_safe`);
- pkgdown renders each article with `callr::r_safe`.

processx starts every child in a session of its own (`setsid()`),
so no signal to R's process group reaches it.
R stops these children only when it unwinds, which it does on SIGINT,
but not on SIGTERM, SIGHUP or SIGKILL.
The children then keep running with PPID 1, often at full CPU.
They notice that R is gone only when they write to it (SIGPIPE);
busy testthat workers don't, and finished `R CMD build`s were seen deadlocked in R's SIGPIPE handler on macOS.
covr uses `system()`, whose children stay in R's process group.

## What does not help

- processx `supervise = TRUE`: testthat and `rcmdcheck()` don't set it and offer no way to.
  It also sends SIGTERM only to the child's PID:
  for `R CMD build`/`check` that is the `sh Rcmd` script, and the R under it survives (measured).
- `cleanup_tree` and `ps::ps_kill_tree()` find descendants by an environment variable,
  which macOS doesn't let other processes read for restricted binaries.
  A watchdog built on it was dropped in [#331](https://github.com/dataheld/nullkomma/pull/331).
- process-compose 1.124.0 knows only process groups and sessions, not namespaces or cgroups.
- Upstream changes to testthat or rcmdcheck: ruled out in [#329](https://github.com/dataheld/nullkomma/issues/329).

## Fix

R must get SIGINT, or the kernel must contain its children.

- `shutdown.signal = 2` on `r-test`, `r-test-coverage`, `r-check` and `r-build-site` ([#327](https://github.com/dataheld/nullkomma/pull/327)):
  process-compose stops each process in its own process group with this signal.
- `r-contain` runs `Rscript` in these tasks.
  `nk <task>` uses `process-compose run`, which leaves the task in the caller's process group,
  so a closed terminal (SIGHUP) or a timeout (SIGTERM, SIGKILL) signals R directly:
  - Linux ([`linux.sh`](linux.sh)): a PID namespace of its own;
    when its init ends, however it ends, the kernel kills every process in it.
  - macOS ([`darwin.sh`](darwin.sh)): R runs in a process group of its own,
    and the first SIGHUP, SIGINT or SIGTERM reaches it as SIGINT.
    Delete this file, and the `isDarwin` branch in [`default.nix`](default.nix), once macOS is no longer supported.
- `nk mcp` stops process-compose when its stdin ends ([#330](https://github.com/dataheld/nullkomma/issues/330), `modules/core/tasks.nix`).
  process-compose ignores the end of stdin, which is all an MCP client that quits or crashes leaves behind.

## Measured

Two parallel testthat workers, each keeping a CPU busy; one way of stopping `r-test`:

| Stopped by                                                     | `main` with [#327](https://github.com/dataheld/nullkomma/pull/327), macOS | now, macOS            | now, Linux   |
| -------------------------------------------------------------- | ------------------------------------------------------------------------- | --------------------- | ------------ |
| `nk r-test` in a terminal, window closed (SIGHUP to its group) | both workers left, 100% CPU each                                          | stopped               | stopped      |
| `nk r-test`, SIGTERM to its group (shell or agent timeout)     | both workers left, 100% CPU each                                          | stopped               | stopped      |
| `nk r-test`, SIGKILL to its group                              | both workers left                                                         | **both workers left** | stopped      |
| `nk r-test` in a terminal, Ctrl-C                              | stopped                                                                   | stopped               | not measured |
| `process-compose up r-test` in a terminal, window closed       | stopped                                                                   | stopped               | not measured |
| `nk mcp` running `r-test` for an agent, client killed          | everything left, workers at 100% CPU                                      | stopped               | not measured |

The SIGKILL row on macOS remains open: nothing in macOS contains processes that left their session.
Measured with the scripts described in [#331](https://github.com/dataheld/nullkomma/pull/331) and with these checks:
`r-test-stopped-by-{hup,term,kill}` (`kill` on Linux only) and `r-test-stops-workers` in
[`../r.test.nix`](../r.test.nix), `mcp-without-client` in [`../../../core/core.test.nix`](../../../core/core.test.nix).

## History

- [#325](https://github.com/dataheld/nullkomma/issues/325): orphaned testthat workers in [dataheld/crow](https://github.com/dataheld/crow) (restarts of `r-test`).
- [#327](https://github.com/dataheld/nullkomma/pull/327): `shutdown.signal = 2`.
- [#329](https://github.com/dataheld/nullkomma/issues/329): the cases [#327](https://github.com/dataheld/nullkomma/pull/327) left open; the processx `supervise` analysis.
- [#330](https://github.com/dataheld/nullkomma/issues/330): `nk mcp` outlives its client.
- [#331](https://github.com/dataheld/nullkomma/pull/331): this fix; its first version, a watchdog, was reverted.
- [#332](https://github.com/dataheld/nullkomma/pull/332): scratch copies; its `trap 'exit 130' INT` only keeps stopped runs from copying back, unrelated.
- [#333](https://github.com/dataheld/nullkomma/issues/333): `nk mcp` already stops tool calls with the task's `shutdown.signal`.
- [#285](https://github.com/dataheld/nullkomma/issues/285): `nk mcp` hangs and ignores SIGTERM, from a process-compose startup race; a different cause.
- [processx: cleaning up subprocesses](https://processx.r-lib.org/articles/cleanup.html).
