# Dependency-free take on vic/import-tree: list every `.nix` file below `root`,
# skipping anything whose path (relative to `root`) contains a `/_` segment.
lib: root:
let
  relative = path: lib.removePrefix (toString root) (toString path);
in
builtins.filter (path: lib.hasSuffix ".nix" (toString path) && !lib.hasInfix "/_" (relative path)) (
  lib.filesystem.listFilesRecursive root
)
