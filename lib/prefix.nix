# `root` relative to the flake `self`, with a trailing slash (empty at the top).
lib: self: root:
let
  top = toString self.outPath;
  path = toString root;
in
if path == top then
  ""
else
  assert lib.assertMsg (lib.hasPrefix "${top}/" path) "${path} must be inside the flake.";
  "${lib.removePrefix "${top}/" path}/"
