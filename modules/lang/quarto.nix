{
  plugins.quarto =
    {
      config,
      flake-parts-lib,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma.quarto;
      inherit (config.nullkomma) brand privacy;
      prefix = import ../../lib/prefix.nix lib self cfg.root;
      privacyPage = ''

        ---
        title: ${builtins.toJSON privacy.title}
        ---

      ''
      + (
        if lib.length privacy.languages == 1 then
          privacy.policy.${(lib.head privacy.languages).code}
        else
          ''
            ::: {.panel-tabset}
          ''
          + lib.concatMapStrings (language: ''

            # ${language.label}

            ${privacy.policy.${language.code}}
          '') privacy.languages
          + ''

            :::
          ''
      );
    in
    {
      options.nullkomma.quarto = {
        root = lib.mkOption {
          type = lib.types.path;
          default = self.outPath;
          defaultText = lib.literalExpression "self.outPath";
          description = "Quarto project rendered into `packages.site` and served by the `preview` task.";
        };
        extensions = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          example = lib.literalExpression ''{ my-brand = inputs.my-brand + "/_extensions/my-brand"; }'';
          description = "Quarto extensions by name, placed in `_extensions/<name>` (generated and Git-ignored) and in the build.";
        };
        privacy.page = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "privacy.qmd";
          description = "Generated page, relative to `root`, rendering `nullkomma.privacy.sections` if there are any; null to write your own.";
        };
      };
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        {
          options.nullkomma.quarto.package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.quartoMinimal.overrideAttrs (old: {
              # Nixpkgs' Quarto 1.9 emits a key its newer Pandoc no longer accepts.
              postPatch = (old.postPatch or "") + ''
                substituteInPlace bin/quarto.js --replace-fail syntax-highlighting highlight-style
              '';
              postFixup = (old.postFixup or "") + ''
                wrapProgram $out/bin/quarto --prefix PATH : ${lib.makeBinPath [ pkgs.which ]}
              '';
            });
            defaultText = lib.literalMD "`pkgs.quartoMinimal`, patched for Nixpkgs' Pandoc";
            description = "Quarto, without R, Python or TeX; override to add execution engines.";
          };
        }
      );
      config = lib.mkIf cfg.enable {
        nullkomma.generatedPaths = [
          "${prefix}.quarto/**"
          "${prefix}_site/**"
        ];
        nullkomma.gitignore = [
          ".quarto/"
          "_site/"
        ];
        perSystem =
          { config, pkgs, ... }:
          let
            quarto = config.nullkomma.quarto.package;
            brandExtension = (pkgs.formats.yaml { }).generate "_extension.yml" {
              contributes.metadata.project.brand = "origin/${baseNameOf brand.lib.brand}";
            };
            siteBrand = import ../../lib/brand.nix {
              inherit pkgs lib brand;
              privacyHref =
                if cfg.privacy.page != null && privacy.policy != { } then
                  lib.removeSuffix ".qmd" cfg.privacy.page + ".html"
                else
                  null;
            };
          in
          {
            nullkomma.devShell.packages = [ quarto ];
            nullkomma.editor.vscode.extensions = [ "quarto.quarto" ];
            # Quarto watches the working tree and live-reloads the browser itself.
            nullkomma.tasks.preview = {
              skip = true;
              raw = true;
              description = "Serve the site on localhost, re-rendering and reloading on changes";
              packages = [
                pkgs.git
                quarto
              ];
              command = ''
                ${lib.getExe config.nullkomma.tasks.generate-files.package}
                cd "$(git rev-parse --show-toplevel)"/${lib.escapeShellArg prefix}
                exec quarto preview "$@"
              '';
            };
            nullkomma.files =
              lib.mapAttrs' (
                name: source:
                lib.nameValuePair "${prefix}_extensions/${name}" {
                  mode = "generated";
                  directory = true;
                  inherit source;
                }
              ) cfg.extensions
              // {
                "${prefix}_extensions/nullkomma-docs" = {
                  mode = "generated";
                  directory = true;
                  source = pkgs.runCommand "quarto-docs-extension" { } ''
                    mkdir "$out"
                    cp ${siteBrand}/_extension.yml "$out/_extension.yml"
                    cp ${./_quarto/docs.css} "$out/docs.css"
                  '';
                };
                "${prefix}_extensions/nullkomma-brand" = {
                  mode = "generated";
                  directory = true;
                  source = pkgs.runCommand "quarto-brand-adapter" { } ''
                    mkdir "$out"
                    cp ${siteBrand}/dark.scss ${siteBrand}/landmarks.lua "$out/"
                  '';
                };
                "${prefix}_nullkomma-brand.yml" = {
                  mode = "generated";
                  commentPrefix = "#";
                  source = "${siteBrand}/quarto.yml";
                };
              }
              // lib.optionalAttrs (brand != null) {
                "${prefix}_brand" = {
                  mode = "generated";
                  directory = true;
                  source = pkgs.runCommand "quarto-brand" { nativeBuildInputs = [ quarto ]; } ''
                    export HOME="$TMPDIR"
                    mkdir source
                    cp ${brandExtension} source/_extension.yml
                    ln -s ${lib.escapeShellArg "${dirOf brand.lib.brand}"} source/origin
                    quarto use brand ./source --force
                    test -f _brand/_brand.yml
                    mv _brand "$out"
                  '';
                };
              }
              // lib.optionalAttrs (cfg.privacy.page != null && privacy.policy != { }) {
                "${prefix}${cfg.privacy.page}" = {
                  mode = "generated";
                  commentPrefix = "<!--";
                  commentSuffix = " -->";
                  text = privacyPage;
                };
              };
            packages.site = lib.mkDefault (
              pkgs.runCommand "site" { nativeBuildInputs = [ quarto ]; } ''
                cp -r ${config.nullkomma.src} src && chmod -R u+w src && cd src/${lib.escapeShellArg prefix}
                HOME=$TMPDIR quarto render --output-dir "$out"
              ''
            );
          };
      };
    };
}
