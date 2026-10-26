import os
from pathlib import Path
import signal
import subprocess
import sys
import time


observed = Path(os.environ["OBSERVED"])


def count():
    return len(observed.read_text().splitlines()) if observed.exists() else 0


def wait_for(predicate):
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        assert process.poll() is None, f"watcher exited: {process.returncode}"
        if predicate():
            return
        time.sleep(0.1)
    raise AssertionError("R watcher did not react")


def idle():
    baseline = count()
    time.sleep(10)
    assert process.poll() is None
    assert count() == baseline, "R output triggered another test run"


with open(os.environ["TMPDIR"] + "/watcher.log", "w") as log:
    process = subprocess.Popen(
        [sys.argv[1]], stdout=log, stderr=log, start_new_session=True
    )
    try:
        # A real testthat run creates and removes an empty _snaps directory.
        wait_for(lambda: count() >= 1)
        wait_for(lambda: "finished" in observed.read_text())
        idle()

        baseline = count()
        source = Path("R/hello.R")
        source.write_text(source.read_text() + "\n")
        wait_for(lambda: count() > baseline)
        wait_for(lambda: observed.read_text().splitlines()[-1] == "finished")
        idle()

        snaps = Path("tests/testthat/_snaps")
        snaps.mkdir(exist_ok=True)
        snapshot = snaps / "watch.md"
        expected = (
            '# watcher snapshot\n\n    Code\n      cat("hello\\n")\n'
            "    Output\n      hello\n\n"
        )
        snapshot.write_text(expected)
        modified = snapshot.stat().st_mtime_ns
        baseline = count()
        Path("tests/testthat/test-watch.R").write_text(
            'test_that("watcher snapshot", {\n'
            '  expect_snapshot(cat("hello\\n"), cran = TRUE)\n'
            '})\n'
        )
        wait_for(lambda: count() > baseline)
        wait_for(lambda: observed.read_text().splitlines()[-1] == "finished")
        idle()
        assert snapshot.stat().st_mtime_ns == modified, "unchanged snapshot was rewritten"

        # Expected snapshots remain inputs; mismatch files are outputs.
        baseline = count()
        snapshot.write_text(expected.replace("      hello\n", "      goodbye\n"))
        wait_for(lambda: count() > baseline)
        wait_for(lambda: (snaps / "watch.new.md").exists())
        idle()

        baseline = count()
        snapshot.write_text(expected)
        wait_for(lambda: count() > baseline)
        wait_for(lambda: observed.read_text().splitlines()[-1] == "finished")
        idle()

        # Whole-file snapshots and variants use the same .new.<extension> rule.
        baseline = count()
        reference = snaps / "variant" / "watch-file" / "example.txt"
        reference.parent.mkdir(parents=True)
        reference.write_text("hello\n")
        Path("tests/testthat/test-watch-file.R").write_text(
            'test_that("whole-file snapshot", {\n'
            '  path <- tempfile(fileext = ".txt")\n'
            '  writeLines("hello", path)\n'
            '  expect_snapshot_file(path, "example.txt", variant = "variant")\n'
            '})\n'
        )
        wait_for(lambda: count() > baseline)
        wait_for(lambda: observed.read_text().splitlines()[-1] == "finished")
        idle()

        baseline = count()
        reference.write_text("goodbye\n")
        wait_for(lambda: count() > baseline)
        wait_for(lambda: reference.with_name("example.new.txt").exists())
        idle()
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=15)
