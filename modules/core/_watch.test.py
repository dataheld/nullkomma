import os
from pathlib import Path
import subprocess
import sys
import time


def wait_for(predicate, process):
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        assert process.poll() is None, f"watcher exited: {process.returncode}"
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError("watcher did not react")


observed = Path(os.environ["OBSERVED"])
hold = Path(os.environ["HOLD"])


def count(word="finished"):
    return observed.read_text().splitlines().count(word) if observed.exists() else 0


def settle(process):
    previous = count()
    stable = 0
    for _ in range(200):
        time.sleep(0.1)
        assert process.poll() is None
        current = count()
        stable = stable + 1 if current == previous else 0
        previous = current
        if stable >= 20:
            return previous
    raise AssertionError("watcher did not settle; possible output feedback loop")


with open(os.environ["TMPDIR"] + "/watcher.log", "w") as log:
    process = subprocess.Popen([sys.argv[1]], stdout=log, stderr=log, start_new_session=True)
    try:
        wait_for(lambda: Path("output/result").exists(), process)
        baseline = settle(process)
        Path("output/generated").write_text("not an input")
        Path("prepared").write_text("prerequisite output")
        Path("external-output").write_text("another task output")
        Path("local-ignore").write_text("explicit exclusion")
        time.sleep(1)
        assert count() == baseline, "excluded path triggered a run"

        saved = Path("content-inputs/saved")
        saved.touch()
        saved.write_bytes(saved.read_bytes())
        directory = Path("content-inputs/empty")
        directory.mkdir()
        directory.rmdir()
        time.sleep(1)
        assert count() == baseline, "unchanged content triggered a run"

        for path in [saved, Path("content-inputs/new")]:
            for change in [
                lambda: path.write_text("changed content"),
                path.unlink,
            ]:
                baseline = settle(process)
                change()
                wait_for(lambda: count() > baseline, process)

        baseline = settle(process)
        Path("content-inputs").rmdir()
        time.sleep(1)
        assert count() == baseline, "empty directory deletion triggered a run"
        Path("content-inputs").mkdir()
        time.sleep(1)
        assert count() == baseline, "empty directory creation triggered a run"

        for change in [
            lambda: Path("ignored-input").write_text("Git ignores are not build exclusions"),
            lambda: Path("new-input").write_text("new files are inputs"),
            lambda: Path("new-input").unlink(),
            lambda: Path("replacement").write_text("atomic save"),
            lambda: Path("replacement").replace("input"),
        ]:
            baseline = settle(process)
            change()
            wait_for(lambda: count() > baseline, process)

        baseline = settle(process)
        hold.touch()
        Path("input").write_text("busy")
        wait_for(lambda: count("started") > baseline, process)
        started = count("started")
        Path("ignored-input").write_text("changed while busy")
        time.sleep(0.5)
        hold.unlink()
        wait_for(lambda: count("started") > started, process)
        settle(process)

        baseline = count()
        Path("input").write_text("broken")
        wait_for(lambda: count("started") > baseline, process)
        time.sleep(0.5)
        assert Path("output/result").read_text() == "busy"
        Path("input").write_text("fixed")
        wait_for(lambda: Path("output/result").read_text() == "fixed", process)

        Path("destination").write_text("other-output")
        wait_for(lambda: Path("other-output/result").exists(), process)
        baseline = settle(process)
        Path("other-output/generated").write_text("new destination is also excluded")
        time.sleep(1)
        assert count() == baseline
    finally:
        if process.poll() is None:
            os.killpg(process.pid, 15)
            process.wait(timeout=10)

stamp = Path(".nullkomma/processes/test/dependency.ok")
stamp.parent.mkdir(parents=True)
stamp.touch()
notification = Path(os.environ["TMPDIR"]) / "stamp-notified"
process = subprocess.Popen(
    [
        sys.argv[2],
        "--postpone",
        "--on-busy-update",
        "queue",
        "--watch",
        str(stamp),
        "--",
        "touch",
        str(notification),
    ],
    start_new_session=True,
)
try:
    time.sleep(1)
    stamp.touch()
    wait_for(notification.exists, process)
finally:
    if process.poll() is None:
        os.killpg(process.pid, 15)
        process.wait(timeout=10)
