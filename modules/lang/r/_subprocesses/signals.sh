# shellcheck shell=bash
# Runs the command in a process group of its own, and passes the first SIGHUP, SIGINT or SIGTERM on to it as SIGINT.
# Only an interrupt makes R unwind and stop the subprocesses that processx started in sessions of their own.
# The fallback where the kernel cannot contain them (macOS, Linux without user namespaces): a SIGKILL to R still leaves them running.
set -m
"$@" &
command=$!
trap 'trap "" HUP INT TERM; kill -INT -- -"$command" 2>/dev/null || true' HUP INT TERM
status=0
while kill -0 "$command" 2>/dev/null; do
  if wait "$command"; then status=0; else status=$?; fi
done
exit "$status"
