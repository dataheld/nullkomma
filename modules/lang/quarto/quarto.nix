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
      inherit (config.nullkomma) privacy;
      prefix = import ../../../lib/prefix.nix lib self cfg.root;
      privacyPage = ''

        ---
        title: ${builtins.toJSON privacy.title}
        sidebar: false
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
              # shortcut: `patches` and `postPatch` make Nixpkgs 26.05's Quarto 1.9 work with
              # its Pandoc 3.7; drop them once NixOS/nixpkgs#569134 reaches our pin, see
              # https://github.com/dataheld/nullkomma/issues/212.
              patches = (old.patches or [ ]) ++ [ ../../../patches/quarto.patch ];
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
        # nkdocs, a Quarto extension contributing a project type: stock Quarto docs features, nothing brand-specific.
        nullkomma.quarto.extensions.nkdocs = ./_nkdocs;
        nullkomma.generatedPaths = [
          "${prefix}.quarto/**"
          "${prefix}_site/**"
          "${prefix}.luarc.json"
        ];
        nullkomma.gitignore = [
          ".quarto/"
          "_site/"
          # Quarto's Lua editor hints, pointing at its store path.
          ".luarc.json"
        ];
        perSystem =
          { config, pkgs, ... }:
          let
            quarto = config.nullkomma.quarto.package;
            render = ''quarto render "$@"'';
            task = description: command: {
              skip = true;
              raw = true;
              inherit description;
              packages = [
                pkgs.git
                quarto
              ];
              command = ''
                ${lib.getExe config.nullkomma.tasks.generate-files.package}
                cd "$(git rev-parse --show-toplevel)"/${lib.escapeShellArg prefix}
                exec ${command}
              '';
            };
          in
          {
            nullkomma.devShell.packages = [ quarto ];
            nullkomma.editor.vscode.extensions = [ "quarto.quarto" ];
            nullkomma.tasks.build-site = task "Render the working-tree site locally (Quarto output directory)" render;
            # Quarto watches the working tree and live-reloads the browser itself.
            nullkomma.tasks.preview = task "Serve the site on localhost, re-rendering and reloading on changes" ''quarto preview "$@"'';
            nullkomma.files =
              lib.mapAttrs' (
                name: source:
                lib.nameValuePair "${prefix}_extensions/${name}" {
                  mode = "generated";
                  directory = true;
                  inherit source;
                }
              ) cfg.extensions
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
                HOME=$TMPDIR ${render} --output-dir "$out"
              ''
            );
          };
      };
    };
}
