{
  plugins.direnv =
    {
      config,
      lib,
      options,
      self,
      ...
    }:
    let
      root = "${toString self.outPath}/";
      within = dir: path: lib.hasPrefix dir "${toString path}/";
      # `use flake` watches only the root flake; partitions have their own sources.
      sources = lib.filter (path: builtins.isPath path && within root path) (
        lib.concatMap (
          { configuration, ... }:
          let
            inherit (configuration.options) extraInputsFlake module;
          in
          lib.optional extraInputsFlake.isDefined extraInputsFlake.value
          ++ map (definition: definition.value) module.definitionsWithLocations
        ) (lib.attrValues options.partitions.valueMeta.attrs or { })
      );
      dirs = lib.filter lib.filesystem.pathIsDirectory sources;
      watch = command: path: "${command} ${lib.escapeShellArg (lib.removePrefix root (toString path))}\n";
    in
    {
      config = lib.mkIf config.nullkomma.direnv.enable {
        nullkomma.gitignore = [ ".direnv/" ];
        perSystem.nullkomma = {
          editor.vscode = {
            extensions = [ "arrterian.nix-env-selector" ];
            settings = lib.mapAttrs (_: lib.mkDefault) {
              "nixEnvSelector.nixFile" = "\${workspaceFolder}/flake.nix";
              "nixEnvSelector.useFlakes" = true;
              "nixEnvSelector.suggestion" = false;
            };
          };
          files.".envrc".text = ''
            # shellcheck shell=bash
            use flake
          ''
          + lib.concatStrings (
            lib.unique (
              map (watch "watch_dir") dirs
              ++ map (watch "watch_file") (
                lib.filter (path: !lib.any (dir: within "${toString dir}/" path) dirs) sources
              )
            )
          );
        };
      };
    };
}
