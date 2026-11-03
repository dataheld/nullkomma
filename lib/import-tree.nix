# Dependency-free take on vic/import-tree: list every `.nix` file below `root`,
# if it exists, skipping any path (relative to `root`) with a `/_` segment.
lib: root:
let
  relative = path: lib.removePrefix (toString root) (toString path);
in
lib.optionals (builtins.pathExists root) (
  builtins.filter (path: lib.hasSuffix ".nix" (toString path) && !lib.hasInfix "/_" (relative path)) (
    lib.filesystem.listFilesRecursive root
  )
)
