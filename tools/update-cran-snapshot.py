#!/usr/bin/env python3
"""Update lib/cran-snapshot.json to match the CRAN update date of nixpkgs in flake.lock."""
import json
import pathlib
import urllib.request

root = pathlib.Path(__file__).resolve().parents[1]
lock = json.loads((root / "flake.lock").read_text())
rev = lock["nodes"]["nixpkgs"]["locked"]["rev"]

url = f"https://api.github.com/repos/NixOS/nixpkgs/commits?path=pkgs/development/r-modules/cran-packages.json&sha={rev}&per_page=10"
req = urllib.request.Request(url, headers={"User-Agent": "nullkomma"})
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        commits = json.loads(resp.read().decode("utf-8"))
        for c in commits:
            msg = c["commit"]["message"].splitlines()[0]
            date = c["commit"]["committer"]["date"][:10]
            if "update" in msg.lower():
                (root / "lib/cran-snapshot.json").write_text(json.dumps({"date": date}, indent=2) + "\n")
                print(f"Updated CRAN snapshot date to {date} (commit: {msg})")
                break
except Exception as e:
    print(f"Warning: could not update CRAN snapshot date from GitHub API: {e}")
