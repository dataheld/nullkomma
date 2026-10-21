{
  plugins.markdown =
    { config, lib, ... }:
    {
      config.perSystem =
        { pkgs, ... }:
        let
          rules = config.nullkomma.lint.markdown;
        in
        lib.mkIf config.nullkomma.markdown.enable {
          treefmt.programs.rumdl-check = {
            enable = lib.mkDefault true;
            priority = 1;
            # Shared rules are rumdl's user-level config, so a native config replaces them.
            package = pkgs.writeShellScriptBin "rumdl" ''
              XDG_CONFIG_HOME=${
                pkgs.linkFarm "rumdl-config" {
                  "rumdl/rumdl.toml" = (pkgs.formats.toml { }).generate "rumdl.toml" (
                    lib.filterAttrs (_: lib.isAttrs) rules
                    // {
                      global.disable = builtins.attrNames (lib.filterAttrs (_: v: v == false) rules);
                    }
                  );
                }
              } exec ${lib.getExe pkgs.rumdl} "$@"
            '';
          };
          treefmt.settings.formatter.rumdl-check.options = [ "--no-cache" ];
          nullkomma.editor.languageServers.marksman = {
            package = pkgs.marksman;
            command = [
              "marksman"
              "server"
            ];
            filetypes = [ "markdown" ];
          };
          treefmt.programs.mdformat = {
            enable = lib.mkDefault true;
            plugins = lib.mkDefault (ps: [
              ps.mdformat-footnote
              ps.mdformat-frontmatter
              ps.mdformat-gfm
              ps.mdformat-gfm-alerts
            ]);
          };
        };
    };
}
