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
        description = "Directory with the [bats](https://bats-core.readthedocs.io) tests, relative to the project root. If it exists, they become the `bats` check.";
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
        perSystem =
          { config, pkgs, ... }:
          let
            cfg = config.nullkomma.shell.bats;
            bats = if cfg.libraries == [ ] then pkgs.bats else pkgs.bats.withLibraries (_: cfg.libraries);
          in
          lib.mkMerge [
            {
              nullkomma.editor.languageServers.bashls = {
                package = pkgs.bash-language-server;
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
              treefmt.programs = {
                shellcheck.enable = lib.mkDefault true;
                shfmt.enable = lib.mkDefault true;
              };
              treefmt.settings.formatter = {
                shellcheck = {
                  includes = [ "*.bats" ];
                  options = [ "--norc" ];
                };
                shfmt.includes = [ "*.bats" ];
              };
            }
            (lib.mkIf hasTests {
              process-compose.dev.settings.processes = {
                bats = {
                  namespace = "shell";
                  description = "Run the Bats tests";
                  disabled = true;
                  command = pkgs.writeShellApplication {
                    name = "bats";
                    runtimeInputs = [ bats ] ++ cfg.packages;
                    text = ''exec bats "$@" ${lib.escapeShellArg testDir}'';
                  };
                };
                nk-check.depends_on.bats.condition = "process_completed_successfully";
              };
            })
          ];
      };
    };
}
