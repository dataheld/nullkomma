{
  plugins.markdown =
    { config, lib, ... }:
    {
      config.perSystem =
        { pkgs, ... }:
        lib.mkIf config.nullkomma.markdown.enable {
          treefmt.imports = [
            ({ mkFormatterModule, ... }: {
              imports = [
                (mkFormatterModule {
                  name = "markdownlint-cli2";
                  includes = [ "*.md" ];
                })
              ];
            })
          ];
          treefmt.programs.markdownlint-cli2 = {
            enable = lib.mkDefault true;
            priority = 1;
            # `--config` is markdownlint-cli2's base configuration, which native files then extend.
            # shortcut: it also resolves top-level `customRules` from the store; use module names
            # or a subdirectory config if a project needs local rule files.
            package = pkgs.writeShellScriptBin "markdownlint-cli2" ''
              files=()
              for file in "$@"; do files+=(":$file"); done
              exec ${lib.getExe pkgs.markdownlint-cli2} --config ${pkgs.writeText "nullkomma.markdownlint.json" (builtins.toJSON config.nullkomma.lint.markdown)} --fix --no-globs "''${files[@]}"
            '';
          };
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
