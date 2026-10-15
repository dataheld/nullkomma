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
      description = config.nullkomma.r.root + "/DESCRIPTION";
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
      imports = [
        (lib.mkRenamedOptionModule
          [ "nullkomma" "r" "rprofile" "enable" ]
          [ "nullkomma" "r" "nonNix" "enable" ]
        )
      ];
      options.nullkomma.r = {
        root = lib.mkOption {
          type = lib.types.path;
          default = self.outPath;
          defaultText = lib.literalExpression "self.outPath";
          example = lib.literalExpression "./pkg";
          description = "R project directory (containing `DESCRIPTION`); a path literal if not the repo root.";
        };
        description = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = if builtins.pathExists description then description else null;
          defaultText = lib.literalExpression ''root + "/DESCRIPTION" (if it exists)'';
          description = "R DESCRIPTION file, where R dependencies are declared; `nix run .#r-lock` resolves them into `nullkomma.r.lockfile`.";
        };
        lockfile = lib.mkOption {
          type = lib.types.path;
          default = config.nullkomma.r.root + "/pkg.lock";
          defaultText = lib.literalExpression ''root + "/pkg.lock"'';
          description = ''
            pak lockfile (`pak::lockfile_create()`) of `nullkomma.r.description`, written by
            `nix run .#r-lock` and committed. It decides which R packages are installed;
            nixpkgs decides their versions (see `nullkomma.r.allowOffNixpkgs`).
          '';
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
        nonNix = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether `write-files` supplies committed `.Renviron`, `.Rprofile`, `.Rbuildignore`
              and a non-Nix development section in README.md. The profile sets
              the PPM snapshot and a writable project library outside Nix shells.
              Disabled by default; enable for collaborators who do not use Nix.
            '';
          };
        };
        fields = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default =
            rlib.defaultFields
            ++ lib.optionals (config.nullkomma.r.description != null) (
              rlib.configNeedsFields (builtins.readFile config.nullkomma.r.description)
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
