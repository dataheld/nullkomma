{ inputs, ... }:
{
  plugins.r =
    {
      config,
      lib,
      self,
      ...
    }:
    let
      rlib = import ../../../lib/r.nix { inherit lib; };
      # Extract snapshot date directly from the flake input's sourceInfo.
      # If nixpkgs-r has an explicit date ref (e.g. rstats-on-nix/YYYY-MM-DD), use it.
      # Otherwise format the locked commit date (lastModifiedDate: "YYYYMMDDhhmmss" -> "YYYY-MM-DD").
      sourceInfo = inputs.nixpkgs-r.sourceInfo or { };
      defaultSnapshot =
        if sourceInfo ? ref && builtins.match "[0-9]{4}-[0-9]{2}-[0-9]{2}" sourceInfo.ref != null then
          sourceInfo.ref
        else if sourceInfo ? lastModifiedDate then
          let
            d = sourceInfo.lastModifiedDate;
          in
          "${builtins.substring 0 4 d}-${builtins.substring 4 2 d}-${builtins.substring 6 2 d}"
        else
          "latest";
    in
    {
      options.nullkomma.r = {
        root = lib.mkOption {
          type = lib.types.path;
          default = self.outPath;
          defaultText = lib.literalExpression "self.outPath";
          example = lib.literalExpression "./pkg";
          description = "R package directory (containing `DESCRIPTION` and its pak lockfile `pkg.lock`, written by `nix run .#r-lock`); a path literal inside the flake if not its root.";
        };
        prefix = lib.mkOption {
          type = lib.types.str;
          internal = true;
          readOnly = true;
          default =
            let
              root = toString config.nullkomma.r.root;
              top = toString self.outPath;
            in
            if root == top then
              ""
            else if lib.hasPrefix "${top}/" root then
              "${lib.removePrefix "${top}/" root}/"
            else
              throw "nullkomma.r.root must be inside the flake.";
          description = "`root` relative to the flake, with a trailing slash (empty at the top).";
        };
        locked = lib.mkOption {
          type = lib.types.nullOr lib.types.raw;
          internal = true;
          readOnly = true;
          default =
            let
              lockfile = config.nullkomma.r.root + "/pkg.lock";
            in
            if builtins.pathExists lockfile then lib.importJSON lockfile else null;
          description = "`pkg.lock`, the pak lockfile of DESCRIPTION written by `nix run .#r-lock`; null while missing.";
        };
        allowOffNixpkgs = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether to allow R packages that nixpkgs does not provide: pinned `Remotes:`
            (`owner/repo@commit`, `git::`, `url::`, `pkg@version`, `cran::pkg@version`) and CRAN
            packages not (yet) in nixpkgs. They are built from the sources pinned in the lockfile
            (commits, or `nullkomma.r.hashes`), against nixpkgs' versions of their dependencies.
            Disabled by default, so that every R package is pinned by `flake.lock` and built and
            tested by nixpkgs.
          '';
        };
        hashes = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            digest = "sha256-gsTRSZlLikqa+TD1qOR0IIKZNavtQfP5Aw6UtqSPAyE=";
          };
          description = ''
            Hashes of R packages fetched by URL (`url::`, `pkg@version`, CRAN packages missing from
            nixpkgs) when `nullkomma.r.allowOffNixpkgs` is set; pak's lockfile has no hashes of
            these URLs. Get one with `nix store prefetch-file <url>`.
          '';
        };
        snapshot = lib.mkOption {
          type = lib.types.str;
          default = defaultSnapshot;
          defaultText = lib.literalExpression "CRAN snapshot date of nixpkgs-r";
          description = "CRAN snapshot date corresponding to the package set in `nixpkgs-r`, for PPM and non-Nix interop.";
        };
        ppmUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://packagemanager.posit.co/cran/${config.nullkomma.r.snapshot}";
          defaultText = lib.literalExpression ''"https://packagemanager.posit.co/cran/''${snapshot}"'';
          description = "Posit Package Manager (PPM) repository URL corresponding to `nullkomma.r.snapshot`.";
        };
        fields = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default =
            let
              description = config.nullkomma.r.root + "/DESCRIPTION";
            in
            rlib.defaultFields
            ++ lib.optionals (builtins.pathExists description) (
              rlib.configNeedsFields (builtins.readFile description)
            );
          defaultText = lib.literalMD "`Depends`, `Imports`, `LinkingTo`, `Suggests`, and all `Config/Needs/*` fields in DESCRIPTION";
          description = "DESCRIPTION fields whose packages pak resolves. Override with only `Depends`, `Imports` and `LinkingTo` for runtime-only dependencies.";
        };
        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "devtools" ];
          description = "Extra R packages from nixpkgs (e.g. dev tooling not in DESCRIPTION); pak and languageserver are always included.";
        };
      };
    };
}
