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
        description = "Repository-relative globs for generated outputs, including directory descendants, which are neither formatted, linted nor checked for duplication. Plugins contribute their outputs; projects may add their own.";
      };
      options.nullkomma.lint.markdown = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Shared Markdown lint rules in markdownlint style (`MD013 = false;` or rule settings), used as rumdl's user-level config: a native .rumdl.toml or .markdownlint.* replaces them.";
      };
      options.nullkomma.lint.typos = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Shared typos TOML settings, merged with discovered native configuration. Explicit shared settings take precedence, as with typos --config; projects can override these Nix defaults.";
      };
      options.nullkomma.lint.yaml = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Shared yamllint defaults, used as yamllint's user-global config: a native .yamllint replaces them.";
      };
      config.perSystem =
        let
          enabled = config.nullkomma.treefmt.enable or false;
          inherit (config.nullkomma) generatedPaths;
        in
        { config, ... }:
        {
          treefmt = {
            flakeFormatter = lib.mkDefault enabled;
            flakeCheck = lib.mkDefault enabled;
            # Also what other tools, like jscpd, skip as not hand-written.
            settings.excludes =
              generatedPaths
              ++ lib.concatLists (
                lib.mapAttrsToList (path: file: [ path ] ++ lib.optional file.directory "${path}/**") (
                  lib.filterAttrs (_: file: file.enable) config.nullkomma.files
                )
              );
          };
        };
    };
  plugins.treefmt =
    { config, lib, ... }:
    let
      enabled = config.nullkomma.treefmt.enable;
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
        };
    };
}
