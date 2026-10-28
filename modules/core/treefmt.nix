{ inputs, ... }:
{
  framework =
    { config, lib, ... }:
    {
      # treefmt is how plugins format and lint: they set `treefmt.programs`, and the
      # framework runs them via `nix fmt`, the check, editors and the `treefmt` task.
      imports = [ inputs.treefmt-nix.flakeModule ];
      options.nullkomma.generatedPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Repository-relative globs for generated outputs, including directory descendants, which are neither formatted, linted nor checked for duplication. Plugins contribute their outputs; projects may add their own.";
      };
      # Shared, so plugins can adjust each other's linters; native config files are not read.
      options.nullkomma.lint =
        lib.mapAttrs
          (
            _: description:
            lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
              inherit description;
            }
          )
          {
            markdown = "Markdown lint rules in markdownlint style (`MD013 = false;` or rule settings), for rumdl.";
            typos = "Typos TOML settings.";
            actionlint = "Actionlint YAML settings.";
            gitleaks = "Gitleaks TOML settings for working-tree and history scans; upstream rules are kept.";
            jscpd = "Jscpd JSON settings; `ignore` extends treefmt's exclusions, `threshold` defaults to zero.";
          };
      config.perSystem =
        let
          inherit (config.nullkomma) generatedPaths;
        in
        { config, ... }:
        {
          treefmt = {
            # Also what other tools, like jscpd, skip as not hand-written.
            settings.excludes =
              generatedPaths
              ++ lib.concatLists (
                lib.mapAttrsToList (path: file: [ path ] ++ lib.optional file.directory "${path}/**") (
                  lib.filterAttrs (_: file: file.enable) config.nullkomma.files
                )
              );
          };
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
          nullkomma.tasks.treefmt = {
            description = "Format and lint all files";
            packages = [ config.treefmt.build.wrapper ];
            command = ''exec treefmt "$@"'';
          };
        };
    };
}
