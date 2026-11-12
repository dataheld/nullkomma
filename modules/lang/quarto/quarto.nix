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
        repo-actions: false
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
          description = "Quarto project rendered into `packages.site` and served by the `quarto-preview` task.";
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
              # shortcut: add Quarto's missing runtime dependency;
              # drop once Nixpkgs supplies it, see
              # https://github.com/dataheld/nullkomma/issues/107.
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
        nullkomma.agents.browser.enable = true;
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
            quartoProcess = description: command: args: {
              namespace = "quarto";
              inherit description;
              working_dir = "./${prefix}";
              command = pkgs.writeShellApplication {
                name = "quarto-${command}";
                runtimeInputs = [ quarto ];
                text = ''exec quarto ${lib.escapeShellArgs ([ command ] ++ args)} "$@"'';
              };
            };
          in
          {
            nullkomma.devShell.packages = [ quarto ];
            nullkomma.browse.servers = [ "quarto-preview" ];
            nullkomma.editor.vscode.extensions = [ "quarto.quarto" ];
            process-compose.dev.settings.processes = {
              quarto-render = quartoProcess "Render the Quarto site" "render" [ ] // {
                disabled = true;
              };
              all.depends_on.quarto-render.condition = "process_completed_successfully";
              # Quarto watches the working tree and live-reloads the browser itself.
              quarto-preview =
                quartoProcess "Serve the site on localhost, re-rendering and reloading on changes" "preview" [
                  "--no-browser"
                ]
                // {
                  depends_on.quarto-preview-includes.condition = "process_started";
                  ready_log_line = "Browse at";
                };
              # shortcut: `quarto preview` misses changes to included files,
              # quarto-dev/quarto-cli#2795; ask it to re-render pages with includes
              # through its undocumented render URL. Drop this once that is fixed,
              # see https://github.com/dataheld/nullkomma/issues/289.
              quarto-preview-includes = {
                namespace = "quarto";
                # Runs at the Git root, as includes may reach beyond the project.
                watch.paths = [
                  {
                    path = ".";
                    include = [ "*.md" ];
                    exclude = [
                      ".git"
                      ".quarto"
                      "_site"
                    ];
                  }
                ];
                command = pkgs.writeShellApplication {
                  name = "quarto-preview-includes";
                  runtimeInputs = [
                    config.process-compose.dev.package
                    pkgs.curl
                    pkgs.gnugrep
                  ];
                  text = ''
                    # Before the preview listens, it renders everything itself.
                    port=$(process-compose process ports quarto-preview | grep -o '[0-9]\+' | head -n 1) || exit 0
                    cd "./${prefix}"
                    pages=$(grep -rlF --include='*.qmd' --exclude-dir=_site --exclude-dir=.quarto '{{< include' .) || [ $? -eq 1 ]
                    for page in $pages; do
                      echo "Re-rendering ''${page#./}"
                      curl -fsS -o /dev/null "http://127.0.0.1:$port/90B3C9E8-0DBC-4BC0-B164-AA2D5C031B28/''${page#./}"
                    done
                  '';
                };
              };
            };
            packages.site = lib.mkDefault (
              config.nullkomma.sandbox {
                process = "quarto-render";
                output = "${prefix}_site";
              }
            );
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
          };
      };
    };
}
