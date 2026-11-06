{
  plugins.python =
    { config, lib, ... }:
    let
      generated = [
        ".venv"
        ".pytest_cache"
        ".ruff_cache"
        ".coverage"
        "coverage.xml"
        "htmlcov"
        "__pycache__"
        "*.egg-info"
      ];
    in
    {
      config.nullkomma = lib.mkIf config.nullkomma.python.enable {
        generatedPaths = lib.concatMap (path: [
          path
          "${path}/**"
          "**/${path}"
          "**/${path}/**"
        ]) generated;
        gitignore = generated;
      };
    };
}
