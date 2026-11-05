import importlib.metadata
import pathlib
import sys

root = pathlib.Path.cwd()
distribution = importlib.metadata.distribution(sys.argv[1])
if pathlib.Path(distribution.locate_file("")).resolve() != root:
    raise RuntimeError("The installed wheel's metadata was not selected.")
for entry in distribution.entry_points:
    if entry.group == "console_scripts":
        entry.load()
