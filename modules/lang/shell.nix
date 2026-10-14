{
  plugins.shell =
    {
      config,
      flake-parts-lib,
      lib,
      self,
      ...
    }:
    let
      inherit (config.nullkomma.shell.bats) testDir;
      # Tests only run once the project has them.
      hasTests = builtins.pathExists (self + "/${testDir}");
    in
    {
      options.nullkomma.shell.bats.testDir = lib.mkOption {
        type = lib.types.str;
        default = "test";
        description = "Directory with the [bats](https://bats-core.readthedocs.io) tests, relative to the project root. If it exists, they become the `bats` test.";
      };
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.shell.bats = {
          packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            example = lib.literalExpression "[ pkgs.jq pkgs.curl ]";
            description = "Packages on `PATH` while the bats tests run.";
          };
          libraries = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            example = lib.literalExpression "[ pkgs.bats.libraries.bats-support pkgs.bats.libraries.bats-assert ]";
            description = "[bats libraries](https://bats-core.readthedocs.io/en/stable/writing-tests.html#bats-load-library-load-a-system-wide-library), loadable with `bats_load_library`.";
          };
        };
      };
      config = lib.mkIf config.nullkomma.shell.enable {
        nullkomma.editor.languageServers.bashls = {
          command = [
            "bash-language-server"
            "start"
          ];
          filetypes = [
            "bash"
            "sh"
          ];
        };
        nullkomma.editor.vscode.extensions = [
          "mads-hartmann.bash-ide-vscode"
          "jetmartin.bats"
        ];
        perSystem =
          { config, pkgs, ... }:
          let
            cfg = config.nullkomma.shell.bats;
            bats = if cfg.libraries == [ ] then pkgs.bats else pkgs.bats.withLibraries (_: cfg.libraries);
          in
          lib.mkMerge [
            {
              nullkomma.devshell.packages = [
                pkgs.bash-language-server
                bats
              ];
              treefmt.programs = {
                shellcheck.enable = lib.mkDefault true;
                shfmt.enable = lib.mkDefault true;
              };
              treefmt.settings.formatter = lib.genAttrs [ "shellcheck" "shfmt" ] (_: {
                includes = [ "*.bats" ];
              });
            }
            (lib.mkIf hasTests {
              nullkomma.tests.bats = {
                packages = [ bats ] ++ cfg.packages;
                command = ''bats "$@" ${lib.escapeShellArg testDir}'';
              };
            })
          ];
      };
    };
}
