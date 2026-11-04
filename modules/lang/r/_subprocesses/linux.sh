# shellcheck shell=bash
# Runs the command in a PID namespace of its own.
# When the namespace's init ends, however it ends, the kernel kills every process in it,
# including those that processx started in sessions of their own.
# bash, not R, is the init: an init ignores the signals it has no handler for.
namespace=(--user --map-current-user --pid --fork --kill-child --mount-proc)
if ! unshare "${namespace[@]}" true 2>/dev/null; then
  echo "r-contain: cannot create a PID namespace; R subprocesses may outlive $1." >&2
  exec "$@"
fi
exec unshare "${namespace[@]}" -- "$BASH" -c '"$@"; exit "$?"' init "$@"
