{
  partitions.dev.module.perSystem =
    {
      harness,
      lib,
      pkgs,
      system,
      ...
    }:
    let
      inherit (harness)
        callFlakeWith
        fixtures
        perSystem
        project
        root
        treefmt
        ;
      md = root + "/tests/fixtures/md";
      flake = callFlakeWith {
        nullkomma.generatedPaths = [ "generated/**" ];
        perSystem.nullkomma.files."managed" = {
          mode = "generated";
          directory = true;
          source = root + "/tests/fixtures/r-brand/assets";
        };
      } md;
      # A consumer whose flake check finds `content` unformatted in a new file.
      unformatted =
        file: content:
        (callFlakeWith {
          perSystem.treefmt.projectRoot = pkgs.runCommandLocal "unformatted" { } ''
            cp -R ${md} "$out"
            chmod -R u+w "$out"
            printf %s ${lib.escapeShellArg content} > "$out"/${file}
          '';
        } md).checks.${system}.treefmt;
    in
    {
      nullkomma.nix.unit.tests.testTreefmtProgramsCanBeDisabled = {
        expr = lib.attrNames (
          lib.filterAttrs (
            _: fixture:
            let
              disabled = callFlakeWith {
                perSystem =
                  { options, ... }:
                  {
                    treefmt.programs = lib.mapAttrs (_: _: {
                      enable = lib.mkForce false;
                    }) (options.treefmt.type.getSubOptions [ ]).programs;
                  };
              } fixture.outPath;
            in
            !(builtins.tryEval (perSystem disabled).treefmt.build.configFile.drvPath).success
          ) fixtures
        );
        expected = [ ];
      };
      checks.treefmt-rejects-unformatted-nix = pkgs.testers.testBuildFailure' {
        drv = unformatted "unformatted.nix" "{foo=1;}\n";
        expectedBuilderLogEntries = [
          "diff --git a/unformatted.nix b/unformatted.nix"
          "+{ foo = 1; }"
        ];
      };
      checks.treefmt-rejects-unformatted-md = pkgs.testers.testBuildFailure' {
        drv = unformatted "unformatted.md" "# Title\n* item\n";
        expectedBuilderLogEntries = [
          "diff --git a/unformatted.md b/unformatted.md"
          "+- item"
        ];
      };
      checks.treefmt-skips-generated = pkgs.runCommand "treefmt-skips-generated" { } ''
        ${project md}
        ${treefmt flake}
        for directory in managed/nested generated/nested; do
          mkdir -p "$directory"
          printf 'broken: [\n' > "$directory/bad.yaml"
          printf '[broken]()\n' > "$directory/bad.md"
        done
        format
        format managed/nested/bad.yaml generated/nested/bad.md
        touch "$out"
      '';
    };
}
