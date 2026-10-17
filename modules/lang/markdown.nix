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
              files=()
              for file in "$@"; do files+=(":$file"); done
              exec ${
                lib.getExe (
                  pkgs.markdownlint-cli2.overrideAttrs (old: {
                    postPatch = (old.postPatch or "") + ''
                      # Native rule files otherwise replace the CLI2 fallback wholesale.
                      substituteInPlace markdownlint-cli2.mjs \
                        --replace-fail '"config": markdownlintConfig || markdownlintOptions?.config,' \
                        ${lib.escapeShellArg ''"config": { ...${builtins.toJSON config.nullkomma.lint.markdown}, ...(markdownlintConfig || markdownlintOptions?.config) },''}
                    '';
                  })
                )
              } --fix --no-globs \
                --config ${
                  pkgs.writeText "nullkomma.markdownlint-cli2.jsonc" (
                    builtins.toJSON {
                      config = config.nullkomma.lint.markdown;
                    }
                  )
                } "''${files[@]}"
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
