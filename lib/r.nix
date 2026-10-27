# Helpers for R projects. nullkomma does not parse DESCRIPTION: pak resolves it
# into a lockfile (`nix run .#r-lock`), which Nix reads as JSON.
{ lib }:
rec {
  defaultFields = [
    "Depends"
    "Imports"
    "LinkingTo"
    "Suggests"
  ];

  configNeedsFields =
    text:
    lib.unique (
      lib.concatMap (
        line:
        let
          match = builtins.match "(Config/Needs/[^:[:space:]]+):.*" line;
        in
        lib.optional (match != null) (builtins.head match)
      ) (lib.splitString "\n" text)
    );

  # Match nixpkgs' r-modules/generate-r-packages.R, including reserved names.
  attrName =
    name:
    lib.replaceStrings [ "." ] [ "_" ] (
      {
        import = "r_import";
        "assert" = "r_assert";
      }
      .${name} or name
    );

  # Splits the packages of a pak lockfile (`pak::lockfile_create()`, format 1)
  # into `nixpkgs`, names of packages taken from `available` (nixpkgs'
  # `rPackages`, whatever version pak recorded), and `sources`, fetcher
  # arguments for packages nixpkgs cannot provide (only with `allowOffNixpkgs`):
  # pinned remotes, pinned versions and CRAN packages missing from nixpkgs.
  readLock =
    {
      lock,
      available,
      fields ? defaultFields,
      allowOffNixpkgs ? false,
      hashes ? { },
    }:
    let
      fail = msg: throw "nullkomma.r: ${msg}";
      regenerate = "regenerate it with `nix run .#r-lock`";
      deps = lib.filter (p: p.type == "deps") lock.packages;
      packages = lib.filter (p: p.type != "deps") lock.packages;
      sorted = lib.sort lib.lessThan;
      fromNixpkgs =
        p:
        lib.elem p.type [
          "standard"
          "cran"
          "bioc"
        ]
        && !lib.hasInfix "@" p.ref
        && available ? ${attrName p.package};
      offNixpkgs = lib.filter (p: !fromNixpkgs p) packages;
      fetcher =
        p:
        let
          m = p.metadata;
          subdir = m.RemoteSubdir or "";
        in
        if p.type == "github" then
          {
            fetchTree = {
              type = "github";
              owner = m.RemoteUsername;
              repo = m.RemoteRepo;
              rev = m.RemoteSha;
            };
            inherit subdir;
          }
        else if p.type == "git" then
          {
            fetchTree = {
              type = "git";
              url = m.RemoteUrl;
              rev = m.RemoteSha;
              shallow = true;
            };
            inherit subdir;
          }
        else if
          lib.elem p.type [
            "url"
            "standard"
            "cran"
            "bioc"
          ]
        then
          # pak's `sha256` hashes CRAN's tarball, not necessarily these URLs
          {
            fetchurl = {
              urls = p.sources;
              hash =
                hashes.${p.package}
                  or (fail "`${p.ref}` is fetched from ${lib.head p.sources}, which needs a hash: set `nullkomma.r.hashes.${p.package}` to the hash printed by `nix store prefetch-file ${lib.head p.sources}`.");
            };
          }
        else
          fail "`${p.ref}` is a pak `${p.type}` reference, which nullkomma does not support.";
    in
    if lock.lockfile_version or null != 1 then
      fail "unsupported pak lockfile format; ${regenerate}."
    else if lib.length deps != 1 then
      fail "the lockfile lacks pak's `deps::` entry for DESCRIPTION; ${regenerate}."
    else if sorted (lib.head deps).dep_types != sorted fields then
      fail "the lockfile resolves ${lib.concatStringsSep ", " (lib.head deps).dep_types}, but `nullkomma.r.fields` is ${lib.concatStringsSep ", " fields}; ${regenerate}."
    else if !allowOffNixpkgs && offNixpkgs != [ ] then
      fail "these R packages do not come from nixpkgs: ${
        lib.concatMapStringsSep ", " (p: "`${p.ref}`") offNixpkgs
      }. Remove them (and their `Remotes:`) from DESCRIPTION, or set `nullkomma.r.allowOffNixpkgs = true;` to build them from their pinned sources."
    else
      {
        nixpkgs = map (p: p.package) (lib.filter fromNixpkgs packages);
        sources = lib.listToAttrs (
          map (
            p:
            lib.nameValuePair p.package (
              fetcher p
              // {
                inherit (p) version dependencies;
              }
            )
          ) offNixpkgs
        );
      };
}
