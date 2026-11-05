{
  plugins.python =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.python;
      atRoot = [
        ".venv"
        ".pytest_cache"
        ".ruff_cache"
        ".coverage"
        "coverage.xml"
        "htmlcov"
        "dist"
      ];
      atAnyDepth = [
        "__pycache__"
        "*.egg-info"
      ];
    in
    {
      options.nullkomma.python.generated = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        internal = true;
        readOnly = true;
        description = "Globs of tool output, relative to `root`.";
      };
      config = lib.mkIf cfg.enable {
        nullkomma = {
          python.generated =
            lib.concatMap (path: [
              path
              "${path}/**"
            ]) atRoot
            ++ lib.concatMap (path: [
              "${path}/**"
              "**/${path}/**"
            ]) atAnyDepth;
          generatedPaths = map (path: cfg.prefix + path) cfg.generated;
          gitignore = map (path: "/${cfg.prefix}${path}") atRoot ++ atAnyDepth;
        };
      };
    };
}
