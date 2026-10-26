import os
from pathlib import Path
import signal
import subprocess
import sys
import time


observed = Path(os.environ["OBSERVED"])
snapshot = Path("tests/testthat/_snaps/snapshot.md")
modified = snapshot.stat().st_mtime_ns


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
        wait_for(lambda: count() >= 1)
        wait_for(lambda: "finished" in observed.read_text())
        idle()
        assert snapshot.stat().st_mtime_ns > modified, (
            "stock testthat did not rewrite the snapshot"
        )
        snapshot.write_bytes(snapshot.read_bytes())
        idle()

        baseline = count()
        source = Path("R/hello.R")
        source.write_text(source.read_text() + "\n")
        wait_for(lambda: count() > baseline)
        wait_for(lambda: observed.read_text().splitlines()[-1] == "finished")
        idle()

        snaps = Path("tests/testthat/_snaps")
        failure = snaps / "hello.new.md"
        failure.write_text("snapshot failure output\n")
        idle()
        failure.write_text("changed failure output\n")
        idle()
        failure.unlink()
        idle()

        expected = snapshot.read_text()
        baseline = count()
        snapshot.write_text(expected.replace("      hello\n", "      goodbye\n"))
        wait_for(lambda: count() > baseline)
        wait_for(lambda: (snaps / "snapshot.new.md").exists())
        idle()

        baseline = count()
        (snaps / "snapshot.new.md").replace(snapshot)
        wait_for(lambda: count() > baseline)
        wait_for(lambda: observed.read_text().splitlines()[-1] == "finished")
        idle()

        reference = snaps / "variant/snapshot/example.txt"
        baseline = count()
        reference.write_text("goodbye\n")
        wait_for(lambda: count() > baseline)
        wait_for(lambda: reference.with_name("example.new.txt").exists())
        idle()

        baseline = count()
        reference.with_name("example.new.txt").replace(reference)
        wait_for(lambda: count() > baseline)
        wait_for(lambda: observed.read_text().splitlines()[-1] == "finished")
        idle()

        baseline = count()
        snapshot.unlink()
        wait_for(lambda: count() > baseline)
        wait_for(snapshot.exists)
        idle()

        baseline = count()
        Path("tests/testthat/test-snapshot.R").unlink()
        # Cleanup deletes saved inputs, so it queues one final run.
        wait_for(lambda: count() >= baseline + 4)
        wait_for(lambda: observed.read_text().splitlines()[-1] == "finished")
        wait_for(lambda: not snaps.exists())
        idle()
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=15)
