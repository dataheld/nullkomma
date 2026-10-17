{ inputs, ... }:
{
  framework =
    { config, lib, ... }:
    {
      # Imported by the framework so any plugin can set `treefmt.programs`. Only the
      # `treefmt` plugin turns on `nix fmt` and the check; reading its option with
      # `or false` avoids priority tricks and works when the plugin isn't imported.
      imports = [ inputs.treefmt-nix.flakeModule ];
      options.nullkomma.generatedPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Repository-relative treefmt exclusion globs for generated outputs, including directory descendants. Plugins contribute their outputs; projects may add their own.";
      };
      options.nullkomma.lint.markdown = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Shared markdownlint rule defaults. Native .markdownlint.* files replace these defaults; Nix attributes extend them.";
      };
      config.perSystem.treefmt = {
        flakeFormatter = lib.mkDefault (config.nullkomma.treefmt.enable or false);
        flakeCheck = lib.mkDefault (config.nullkomma.treefmt.enable or false);
      };
    };
  plugins.treefmt =
    { config, lib, ... }:
    let
      enabled = config.nullkomma.treefmt.enable;
      generatedPaths = config.nullkomma.generatedPaths;
    in
    {
      config.perSystem =
        { config, ... }:
        lib.mkIf enabled {
          nullkomma.editor = {
            formatter = {
              package = config.treefmt.build.wrapper;
              command = [
                "treefmt"
                "--stdin"
                "{file}"
              ];
            };
            vscode.extensions = [ "ibecker.treefmt-vscode" ];
            vscode.settings."editor.defaultFormatter" = lib.mkDefault "ibecker.treefmt-vscode";
          };
          # Writes files, so not part of running all tasks.
          nullkomma.tasks.format = {
            skip = true;
            description = "Format and lint all files (treefmt)";
            packages = [ config.treefmt.build.wrapper ];
            command = ''exec treefmt "$@"'';
          };
          treefmt.settings.excludes =
            generatedPaths
            ++ lib.concatLists (
              lib.mapAttrsToList (path: file: [ path ] ++ lib.optional file.directory "${path}/**") (
                lib.filterAttrs (_: file: file.enable) config.nullkomma.files
              )
            );
        };
    };
}
