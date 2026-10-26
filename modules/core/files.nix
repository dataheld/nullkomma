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
                  description = "`source`: written by `write-files`, then a committed source of truth, updated only while unedited. `generated`: written from Nix by `generate-files` (also on entering the dev shell), overwritten when changed and Git-ignored.";
                };
                commentPrefix = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Line-comment prefix for the \"do not edit\" header of generated files (for example // for JSONC) and for section markers. Required for both.";
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
                  description = "Project content `source` is derived from; `write-files` replaces the file while it still matches.";
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
            description = "The flake's source with every generated file in place, as after `generate-files`: where sandboxed checks and site builds start.";
          };
        }
      );
      config.perSystem =
        { config, pkgs, ... }:
        let
          files = lib.filterAttrs (_: f: f.enable) config.nullkomma.files;
          generated = lib.mapAttrs (
            path: f:
            if f.directory then
              f.source
            else
              assert lib.assertMsg (
                f.commentPrefix != null
              ) "Generated file ${path} needs a commentPrefix for its header.";
              pkgs.concatText "nullkomma-generated-${baseNameOf path}" [
                (pkgs.writeText "nullkomma-warning" ''
                  ${f.commentPrefix} Generated by nullkomma. DO NOT EDIT; change the Nix configuration.${f.commentSuffix}
                '')
                f.source
              ]
          ) (lib.filterAttrs (_: f: f.mode == "generated") files);
          task = mode: {
            skip = true;
            description =
              if mode == "source" then
                "Write source-of-truth files; keep your edits and report upstream conflicts"
              else
                "Overwrite Git-ignored files generated from Nix";
            packages = [
              pkgs.coreutils
              pkgs.git
            ];
            command = ''
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
          nullkomma.tasks.write-files = task "source";
          nullkomma.tasks.generate-files = task "generated";
          # Generated files follow the Nix configuration, not the working tree: refresh them on
          # entering the dev shell (direnv re-enters when the flake changes), only if they changed.
          nullkomma.devShell.shellHook = lib.mkIf (generated != { }) ''
            if stamp="$(git rev-parse --git-path nullkomma/files/generated-by 2>/dev/null)" &&
              [ "$(cat "$stamp" 2>/dev/null)" != ${config.nullkomma.tasks.generate-files.package} ]; then
              ${lib.getExe config.nullkomma.tasks.generate-files.package} && echo ${config.nullkomma.tasks.generate-files.package} > "$stamp"
            fi
          '';
        };
    };
}
