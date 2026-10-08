{
  flake.flakeModules.default =
    { config, lib, ... }:
    let
      ignores = lib.unique config.nullkomma.gitignore;
    in
    {
      options.nullkomma.gitignore = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Lines of the generated `.gitignore`; every aspect appends here.";
      };
      config = {
        nullkomma.gitignore = [
          ".direnv/"
          "result"
          "result-*"
        ];
        # Managed files are re-included last, so a global excludesFile (e.g. one ignoring
        # `.vscode/settings.json` or `.envrc`) can't keep them out of the flake source.
        perSystem =
          { config, ... }:
          {
            nullkomma.files.".gitignore".text = lib.concatLines (
              ignores
              ++ [ "# nullkomma-managed files" ]
              ++ map (path: "!/${path}") (lib.attrNames (lib.filterAttrs (_: f: f.enable) config.nullkomma.files))
            );
          };
      };
    };
}
