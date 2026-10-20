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
            package = pkgs.writeShellScriptBin "markdownlint-cli2" ''
              export NULLKOMMA_MARKDOWNLINT_CONFIG=${pkgs.writeText "nullkomma-markdownlint.json" (builtins.toJSON config.nullkomma.lint.markdown)}
              files=()
              for file in "$@"; do files+=(":$file"); done
              exec ${
                lib.getExe (
                  pkgs.markdownlint-cli2.overrideAttrs (old: {
                    patches = (old.patches or [ ]) ++ [ ../../patches/markdownlint-cli2.patch ];
                  })
                )
              } --fix --no-globs "''${files[@]}"
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
