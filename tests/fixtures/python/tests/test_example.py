import subprocess

from nk_example import greeting


def test_greeting() -> None:
    assert greeting() == "Hello from Python"


def test_console_script() -> None:
    assert subprocess.check_output(["nk-example"], text=True) == greeting() + "\n"
