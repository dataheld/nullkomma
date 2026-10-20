{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
    in
    {
      options.nullkomma.r.jarl.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Lint and auto-fix R code with jarl as a treefmt formatter, configured by the project's own jarl.toml.";
      };
      config.perSystem = lib.mkIf cfg.enable (
        { pkgs, ... }:
        {
          treefmt.programs.air.enable = lib.mkDefault true;
          treefmt.settings.formatter.jarl = lib.mkIf cfg.jarl.enable {
            command = lib.getExe (
              # shortcut: nixpkgs' jarl tests fail on Darwin (no cached binary); drop once Hydra builds it.
              if pkgs.stdenv.hostPlatform.isDarwin then
                pkgs.jarl.overrideAttrs { doCheck = false; }
              else
                pkgs.jarl
            );
            options = [
              "check"
              "--fix"
              "--allow-dirty"
              "--allow-no-vcs"
              "--output-format=concise"
            ];
            includes = [
              "*.R"
              "*.r"
            ];
            # fix lints first, then let air format the result
            priority = -1;
          };
        }
      );
    };
}
