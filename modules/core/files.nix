# Files are either a source of truth (written once, then edited and committed)
# or generated from Nix (overwritten on every run and Git-ignored).
{
  framework =
    {
      flake-parts-lib,
      lib,
      self,
      ...
    }:
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        let
          fileModule =
            { name, config, ... }:
            let
              current = self.outPath + "/${name}";
            in
            {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to write `${name}`.";
                };
                mode = lib.mkOption {
                  type = lib.types.enum [
                    "source"
                    "generated"
                  ];
                  default = "source";
                  description = "`source`: written by `nk-write-files`, then a committed source of truth, updated only while unedited. `generated`: written from Nix by `nk-generate-files` (also on entering the dev shell), overwritten when changed and Git-ignored.";
                };
                commentPrefix = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Line-comment prefix for the \"do not edit\" header of generated files (for example // for JSONC) and for section markers; without it, generated files get no header. Required for sections.";
                };
                commentSuffix = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                  description = "Closes the header comment and section markers, for formats without line comments (for example ` -->` with `<!--`).";
                };
                directory = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether `source` is a directory, copied whole and without a header. Generated files only.";
                };
                text = lib.mkOption {
                  type = lib.types.nullOr lib.types.lines;
                  default = null;
                  description = "File content; sets `source`.";
                };
                source = lib.mkOption {
                  type = lib.types.path;
                  description = "Store path whose content is written to `${name}`.";
                };
                initialSource = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  default = null;
                  description = "Project content `source` is derived from; `nk-write-files` replaces the file while it still matches.";
                };
                sections = lib.mkOption {
                  type = lib.types.attrsOf lib.types.lines;
                  default = { };
                  description = "Marked sections nullkomma owns inside an otherwise project-owned source file, by name: replaced in place, else appended, and removed once undeclared. Needs `commentPrefix`.";
                };
              };
              config = lib.mkMerge [
                {
                  source = lib.mkIf (config.text != null) (
                    pkgs.writeText "nullkomma-${lib.replaceStrings [ "/" ] [ "-" ] name}" config.text
                  );
                }
                (lib.mkIf (config.sections != { }) {
                  initialSource = lib.mkIf (builtins.pathExists current) current;
                  text =
                    assert lib.assertMsg (
                      config.commentPrefix != null
                    ) "File ${name} needs a commentPrefix for its sections.";
                    import ./_sections.nix { inherit lib; } {
                      inherit (config) commentPrefix commentSuffix sections;
                    } (if builtins.pathExists current then builtins.readFile current else "");
                })
              ];
            };
        in
        {
          options.nullkomma.files = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule fileModule);
            default = { };
            description = "Files written into the project, keyed by repo-relative path.";
          };
          options.nullkomma.src = lib.mkOption {
            type = lib.types.package;
            readOnly = true;
            description = "The flake's source with every generated file in place, as after `nk-generate-files`: where sandboxed checks and site builds start.";
          };
        }
      );
      config.perSystem =
        { config, pkgs, ... }:
        let
          files = lib.filterAttrs (_: f: f.enable) config.nullkomma.files;
          generated = lib.mapAttrs (
            path: f:
            if f.directory || f.commentPrefix == null then
              f.source
            else
              pkgs.concatText "nullkomma-generated-${baseNameOf path}" [
                (pkgs.writeText "nullkomma-warning" ''
                  ${f.commentPrefix} Generated by nullkomma. DO NOT EDIT; change the Nix configuration.${f.commentSuffix}
                '')
                f.source
              ]
          ) (lib.filterAttrs (_: f: f.mode == "generated") files);
          script =
            name: mode:
            pkgs.writeShellApplication {
              inherit name;
              runtimeInputs = [
                pkgs.coreutils
                pkgs.git
              ];
              text = ''
                mode=${mode}
              ''
              + builtins.readFile ./_files.sh
              + lib.concatStrings (
                lib.mapAttrsToList (
                  path: f:
                  let
                    source =
                      assert lib.assertMsg (
                        !f.directory || mode == "generated"
                      ) "Directory ${path} must be a generated file.";
                      if mode == "generated" then generated.${path} else f.source;
                  in
                  ''
                    process_file ${lib.escapeShellArg path} ${lib.escapeShellArg "${source}"} ${
                      lib.escapeShellArg (if f.initialSource == null then "" else "${f.initialSource}")
                    }
                  ''
                ) (lib.filterAttrs (_: f: f.mode == mode) files)
              )
              + ''
                finish
              '';
            };
          write = script "nk-write-files" "source";
          generate = script "nk-generate-files" "generated";
          task = description: command: {
            namespace = "nullkomma";
            inherit description command;
            disabled = true;
          };
        in
        {
          nullkomma.src = pkgs.runCommand "source" { } (
            ''
              cp -R ${self} "$out"
              chmod -R u+w "$out"
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (path: source: ''
                rm -rf "$out"/${lib.escapeShellArg path}
                mkdir -p "$out"/${lib.escapeShellArg (dirOf path)}
                cp -R ${source} "$out"/${lib.escapeShellArg path}
                chmod -R u+w "$out"/${lib.escapeShellArg path}
              '') generated
            )
          );
          process-compose.dev.settings.processes = {
            nk-write-files = task "Write source-of-truth files; keep your edits and report upstream conflicts" write;
            nk-generate-files = task "Overwrite Git-ignored files generated from Nix" generate;
          };
          # Generated files follow the Nix configuration, not the working tree: refresh them on
          # entering the dev shell (direnv re-enters when the flake changes), only if they changed.
          nullkomma.devShell.shellHook = lib.mkIf (generated != { }) ''
            if stamp="$(git rev-parse --git-path nullkomma/files/generated-by 2>/dev/null)" &&
              [ "$(cat "$stamp" 2>/dev/null)" != ${generate} ]; then
              ${lib.getExe generate} && echo ${generate} > "$stamp"
            fi
          '';
        };
    };
}
