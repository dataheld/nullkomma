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
        assert not Path("tests/testthat/_snaps").exists()

        baseline = count()
        source = Path("R/hello.R")
        source.write_text(source.read_text() + "\n")
        wait_for(lambda: count() > baseline)
        wait_for(lambda: observed.read_text().splitlines()[-1] == "finished")
        idle()

        snaps = Path("tests/testthat/_snaps")
        snaps.mkdir()
        idle()
        failure = snaps / "hello.new.md"
        failure.write_text("snapshot failure output\n")
        idle()
        failure.unlink()
        snaps.rmdir()
        idle()

    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=15)
