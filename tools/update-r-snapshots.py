#!/usr/bin/env python3
"""Append dated rstats-on-nix revisions without changing existing pins."""
import json
import pathlib
import re
import subprocess

path = pathlib.Path(__file__).resolve().parents[1] / "lib/r-snapshots.json"
snapshots = json.loads(path.read_text())
refs = subprocess.check_output(
    ["git", "ls-remote", "--heads", "https://github.com/rstats-on-nix/nixpkgs.git"],
    text=True,
)
for line in refs.splitlines():
    sha, ref = line.split()
    date = ref.removeprefix("refs/heads/")
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        snapshots.setdefault(date, sha)
path.write_text(json.dumps(snapshots, indent=2, sort_keys=True) + "\n")
