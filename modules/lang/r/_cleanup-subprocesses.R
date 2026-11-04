# processx starts subprocesses (testthat workers, R CMD build and check, callr renders) in sessions of their own,
# out of reach of signals to this R's process group, and R stops them only when it unwinds.
# This watchdog, in a session of its own too, waits for this R to end, however it ends:
# the kernel closes the pipe to its stdin even on SIGKILL.
# It then kills every process that inherited the marker, wherever it was reparented to.
local({
  marker <- ps::ps_mark_tree()
  watchdog <- processx::process$new(
    "/bin/sh",
    c(
      "-c",
      'while read -r _; do :; done; exec "$0" --vanilla -e "invisible(ps::ps_kill_tree(commandArgs(TRUE)))" "$1"',
      file.path(R.home("bin"), "Rscript"),
      marker
    ),
    stdin = "|",
    cleanup = FALSE
  )
  # Collecting the process object would close the pipe.
  options(nullkomma.subprocesses = list(marker = marker, watchdog = watchdog))
})
