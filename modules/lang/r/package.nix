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

          projectDcf =
            if cfg.description != null then rlib.parseDcf (builtins.readFile cfg.description) else { };

          describe =
            src:
            let
              dcf = rlib.parseDcf (builtins.readFile "${src}/DESCRIPTION");
            in
            if (rlib.remotesOf dcf) != [ ] then
              throw "nullkomma.r: transitive Remotes are not supported; declare pinned overrides in the project's DESCRIPTION."
            else
              {
                inherit src;
                dcf = dcf;
                package = dcf.Package or (throw "nullkomma.r: ${src}/DESCRIPTION is missing a `Package` field.");
                version = dcf.Version or (throw "nullkomma.r: ${src}/DESCRIPTION is missing a `Version` field.");
                dependencies = map (d: d.name) (
                  rlib.depsOf dcf [
                    "Depends"
                    "Imports"
                    "LinkingTo"
                  ]
                );
              };

          dependencies =
            if cfg.description != null then map (d: d.name) (rlib.depsOf projectDcf cfg.fields) else [ ];

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

          remotes = map parseRemote (rlib.remotesOf projectDcf);

          base = pkgsR.rPackages;
          lookup =
            name:
            final.${rlib.attrName name}
            or (throw "nullkomma.r: R package `${name}` is not in `rPackages` of nixpkgs; add it to `Remotes:` in DESCRIPTION or drop it from DESCRIPTION/extraPackages.");
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
          versions = lib.listToAttrs (
            map (name: lib.nameValuePair name (lib.getVersion (lookup name))) versionNames
          );

          # Validate version constraints in pure Nix
          validateAllConstraints =
            let
              validProject =
                if cfg.description != null then
                  rlib.validateConstraints {
                    dcf = projectDcf;
                    inherit (cfg) fields;
                    inherit versions;
                  }
                else
                  true;
              validRemotes = map (
                r:
                rlib.validateConstraints {
                  inherit (r) dcf;
                  fields = [
                    "Depends"
                    "Imports"
                    "LinkingTo"
                  ];
                  inherit versions;
                }
              ) remotes;
            in
            validProject && lib.all (x: x == true) validRemotes;

          uniqueRemotes = lib.length remotes == lib.length (lib.unique (map (r: r.package) remotes));
          remoteOrder = lib.toposort (a: b: lib.elem a.package b.dependencies) remotes;
        in
        {
          config.nullkomma.r = {
            inherit dependencies;
            package =
              if !uniqueRemotes then
                throw "nullkomma.r: duplicate package names in Remotes."
              else if remoteOrder ? cycle then
                throw "nullkomma.r: dependency cycle between Remotes."
              else if !validateAllConstraints then
                throw "nullkomma.r: version constraint validation failed."
              else
                pkgsR.rWrapper.override { packages = map lookup names; };
          };
        };
    };
}
