{
  flake.flakeModules.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r.jarl;
    in
    {
      options.nullkomma.r.jarl.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Lint and auto-fix R code with jarl as a treefmt formatter.
          Off by default: nixpkgs has no aarch64-darwin binary (upstream tests fail there),
          so it is compiled from source with tests disabled on macOS.
        '';
      };
      config.perSystem =
        { pkgs, ... }:
        {
          treefmt.programs.air.enable = lib.mkDefault true;
          treefmt.settings.formatter.jarl = lib.mkIf cfg.enable {
            command = lib.getExe (
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
        };
    };
}
