# R and its packages come from nixpkgs (inputs.nixpkgs-r, defaulting to nullkomma's nixpkgs).
# `Remotes:` in DESCRIPTION, pinned to a commit, are layered on top.
{ inputs, ... }:
{
  flake.flakeModules.r =
    {
      config,
      flake-parts-lib,
      lib,
      ...
    }:
    let
      cfg = config.nullkomma.r;
      rlib = import ../../../lib/r.nix { inherit lib; };
    in
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.r.snapshot = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "CRAN snapshot date corresponding to `nixpkgs-r`.";
        };
        options.nullkomma.r.ppmUrl = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "PPM repository URL corresponding to `nullkomma.r.snapshot`.";
        };
        options.nullkomma.r.dependencies = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          readOnly = true;
          description = "Package names `nullkomma.r.description` depends on in `nullkomma.r.fields`, as parsed by R itself (base packages excluded).";
        };
        options.nullkomma.r.buildInputs = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.package);
          default = { };
          example = lib.literalExpression "{ sf = [ pkgs.gdal ]; }";
          description = "System libraries to add to the build of an R package, for packages whose needs nixpkgs does not know (typically `Remotes:`).";
        };
        options.nullkomma.r.package = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          description = "R with every package from DESCRIPTION and `nullkomma.r.extraPackages`.";
        };
      };
      config.perSystem =
        { system, config, ... }:
        let
          pcfg = config.nullkomma.r;
          pkgsR = inputs.nixpkgs-r.legacyPackages.${system};

          # IFD: R's own parsers run in a derivation using the pinned R.
          runR =
            pkgs: script: files: args:
            builtins.readFile (
              pkgs.runCommandLocal "r-${baseNameOf script}"
                (
                  {
                    nativeBuildInputs = [ pkgs.R ];
                  }
                  // lib.mapAttrs (name: path: pkgs.writeText name (builtins.readFile path)) files
                )
                ''
                  export HOME="$TMPDIR"
                  {
                    ${args}
                  } > "$out"
                ''
            );
          lines = text: lib.filter (l: l != "") (lib.splitString "\n" text);

          snapshot = cfg.snapshot;
          ppmUrl = cfg.ppmUrl;

          describe =
            src:
            let
              meta = lines (
                runR pkgsR ../../../lib/description-meta.R { description = "${src}/DESCRIPTION"; } ''
                  Rscript ${../../../lib/description-meta.R} "$description"
                ''
              );
            in
            {
              src =
                if
                  lines (
                    runR pkgsR ../../../lib/description-remotes.R { description = "${src}/DESCRIPTION"; } ''
                      Rscript --vanilla ${../../../lib/description-remotes.R} "$description"
                    ''
                  ) != [ ]
                then
                  throw "nullkomma.r: transitive Remotes are not supported; declare pinned overrides in the project's DESCRIPTION."
                else
                  src;
              package = lib.elemAt meta 0;
              version = lib.elemAt meta 1;
              dependencies = depsOf "${src}/DESCRIPTION" [
                "Depends"
                "Imports"
                "LinkingTo"
              ];
            };
          depsOf =
            file: fields:
            lines (
              runR pkgsR ../../../lib/description-deps.R { description = file; } ''
                Rscript ${../../../lib/description-deps.R} "$description" ${lib.escapeShellArgs fields}
              ''
            );

          dependencies = lib.optionals (cfg.description != null) (depsOf cfg.description cfg.fields);

          # Only `owner/repo@<commit>` is accepted: a commit is the one reference
          # that cannot move, which is what makes the lock meaningful.
          parseRemote =
            entry:
            let
              m = builtins.match "([A-Za-z0-9.]+=)?(github::)?([^/@#=:]+)/([^/@#=:]+)@([0-9a-f]{40})" entry;
            in
            if m == null then
              throw "nullkomma.r: Remotes entry `${entry}` must be `owner/repo@<40-character commit sha>` (GitHub, pinned to a commit)."
            else
              let
                remote = describe (
                  builtins.fetchTree {
                    type = "github";
                    owner = lib.elemAt m 2;
                    repo = lib.elemAt m 3;
                    rev = lib.elemAt m 4;
                  }
                );
                alias = lib.elemAt m 0;
              in
              if alias != null && lib.removeSuffix "=" alias != remote.package then
                throw "nullkomma.r: Remotes alias `${alias}` does not match `${remote.package}` in the fetched DESCRIPTION."
              else
                remote;
          remotes = lib.optionals (cfg.description != null) (
            map parseRemote (
              lines (
                runR pkgsR ../../../lib/description-remotes.R { description = cfg.description; } ''
                  Rscript ${../../../lib/description-remotes.R} "$description"
                ''
              )
            )
          );

          base = pkgsR.rPackages;
          lookup =
            name:
            final.${rlib.attrName name}
            or (throw "nullkomma.r: R package `${name}` is not in `rPackages` of nixpkgs-r; pin a newer snapshot or drop it from DESCRIPTION/extraPackages.");
          remoteOverrides = lib.listToAttrs (
            map (
              r:
              let
                attr = rlib.attrName r.package;
                inputs' = map lookup r.dependencies;
              in
              lib.nameValuePair attr (
                if base ? ${attr} then
                  base.${attr}.overrideAttrs (old: {
                    pname = r.package;
                    name = "r-${r.package}-${r.version}";
                    inherit (r) src version;
                    propagatedBuildInputs =
                      inputs' ++ lib.filter (p: !(p ? rCommand)) (old.propagatedBuildInputs or [ ]);
                    nativeBuildInputs = inputs' ++ lib.filter (p: !(p ? rCommand)) (old.nativeBuildInputs or [ ]);
                  })
                else
                  base.buildRPackage {
                    pname = r.package;
                    inherit (r) src version;
                    propagatedBuildInputs = inputs';
                    nativeBuildInputs = inputs';
                  }
              )
            ) remotes
          );
          systemLibraries = lib.mapAttrs' (
            name: libs:
            let
              attr = rlib.attrName name;
            in
            lib.nameValuePair attr (
              (remoteOverrides.${attr} or base.${attr}).overrideAttrs (old: {
                buildInputs = (old.buildInputs or [ ]) ++ libs;
              })
            )
          ) pcfg.buildInputs;
          final = base.override { overrides = remoteOverrides // systemLibraries; };

          names = lib.unique (dependencies ++ cfg.extraPackages ++ [ "languageserver" ]);
          versionNames = lib.unique (names ++ lib.concatMap (r: r.dependencies) remotes);
          versions = pkgsR.writeText "r-selected-versions" (
            lib.concatMapStrings (name: "${name}\t${lib.getVersion (lookup name)}\n") versionNames
          );
          validate =
            file: fields:
            runR pkgsR ../../../lib/description-constraints.R { description = file; } ''
              Rscript --vanilla ${../../../lib/description-constraints.R} "$description" ${versions} ${lib.escapeShellArgs fields}
            '';
          validation =
            lib.optionals (cfg.description != null) [ (validate cfg.description cfg.fields) ]
            ++ map (
              r:
              validate "${r.src}/DESCRIPTION" [
                "Depends"
                "Imports"
                "LinkingTo"
              ]
            ) remotes;
          uniqueRemotes = lib.length remotes == lib.length (lib.unique (map (r: r.package) remotes));
          remoteOrder = lib.toposort (a: b: lib.elem a.package b.dependencies) remotes;
        in
        {
          config.nullkomma.r = {
            inherit snapshot ppmUrl dependencies;
            package =
              if !uniqueRemotes then
                throw "nullkomma.r: duplicate package names in Remotes."
              else if remoteOrder ? cycle then
                throw "nullkomma.r: dependency cycle between Remotes."
              else
                builtins.deepSeq validation (pkgsR.rWrapper.override { packages = map lookup names; });
          };
        };
    };
}
