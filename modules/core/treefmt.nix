{ inputs, ... }:
{
  framework =
    { config, lib, ... }:
    {
      # treefmt is how plugins format and lint: they set `treefmt.programs`, and the
      # framework runs them via `nix fmt`, the check, editors and the `format` task.
      imports = [ inputs.treefmt-nix.flakeModule ];
      options.nullkomma.generatedPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Repository-relative globs for generated outputs, including directory descendants, which are neither formatted, linted nor checked for duplication. Plugins contribute their outputs; projects may add their own.";
      };
      options.nullkomma.lint.markdown = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Markdown lint rules in markdownlint style (`MD013 = false;` or rule settings), passed explicitly to rumdl. Configure here, not in native config files.";
      };
      options.nullkomma.lint.typos = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Typos TOML settings. Passed explicitly with native config discovery disabled.";
      };
      options.nullkomma.lint.actionlint = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Actionlint YAML settings, passed explicitly instead of discovering .github/actionlint.yaml.";
      };
      options.nullkomma.lint.gitleaks = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Gitleaks TOML settings for both working-tree and history scans. Plugin defaults retain upstream rules.";
      };
      options.nullkomma.lint.jscpd = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Jscpd JSON settings. Ignore globs extend treefmt's shared exclusions; the default threshold is zero percent.";
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
