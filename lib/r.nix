# Pure Nix helpers for R projects: parsing DESCRIPTION (DCF) files,
# extracting dependencies, remotes, and validating version constraints
# completely in pure Nix without Import-From-Derivation (IFD).
{ lib }:
rec {
  defaultFields = [
    "Depends"
    "Imports"
    "LinkingTo"
    "Suggests"
  ];

  # Base packages that ship with R itself (priority = "base")
  basePackages = [
    "R"
    "base"
    "compiler"
    "datasets"
    "graphics"
    "grDevices"
    "grid"
    "methods"
    "parallel"
    "profile"
    "splines"
    "stats"
    "stats4"
    "tcltk"
    "tools"
    "translations"
    "utils"
  ];

  # Cheap presence test: DCF field names start a line, continuations are indented.
  hasPackageField = text: lib.any (l: lib.hasPrefix "Package:" l) (lib.splitString "\n" text);

  # nixpkgs mangles CRAN names: data.table -> data_table
  attrName = lib.replaceStrings [ "." ] [ "_" ];

  # Parse a DCF (Debian Control File / RFC 822 format) string into an attribute set of fields.
  parseDcf =
    text:
    let
      lines = lib.splitString "\n" text;
      foldFn =
        acc: line:
        if line == "" then
          acc
        else if lib.hasPrefix " " line || lib.hasPrefix "\t" line then
          let
            last = lib.last acc;
          in
          (lib.init acc) ++ [ (last + " " + lib.trim line) ]
        else
          acc ++ [ line ];
      merged = lib.foldl foldFn [ ] lines;
      parseField =
        line:
        let
          m = builtins.match "([A-Za-z0-9_-]+):[ ]*(.*)" line;
        in
        if m != null then
          {
            name = lib.elemAt m 0;
            value = lib.elemAt m 1;
          }
        else
          null;
      fields = lib.filter (x: x != null) (
        map (
          line:
          let
            f = parseField line;
          in
          if f != null then lib.nameValuePair f.name f.value else null
        ) merged
      );
    in
    lib.listToAttrs fields;

  # Parse a single dependency entry like "withr (>= 3.0.0)" or "stats"
  parseDependency =
    entry:
    let
      trimmed = lib.trim entry;
      m = builtins.match "([A-Za-z0-9.]+)[ ]*(\\(([<>=!]+)[ ]*([0-9a-zA-Z.-]+)\\))?" trimmed;
    in
    if m == null then
      null
    else
      {
        name = lib.elemAt m 0;
        op = lib.elemAt m 2;
        version = lib.elemAt m 3;
      };

  # Extract parsed dependencies from specified fields in a DCF attrset, excluding base packages.
  depsOf =
    dcf: fields:
    let
      rawEntries = lib.concatMap (f: if dcf ? ${f} then lib.splitString "," dcf.${f} else [ ]) fields;
      parsed = lib.filter (d: d != null && !lib.elem d.name basePackages) (
        map parseDependency rawEntries
      );
    in
    parsed;

  # Extract remote entries from the Remotes field as a list of strings
  remotesOf =
    dcf:
    if dcf ? Remotes then
      lib.filter (s: s != "") (map lib.trim (lib.splitString "," dcf.Remotes))
    else
      [ ];

  # Compare versions according to comparison operator
  matchVersion =
    op: v1: v2:
    let
      cmp = builtins.compareVersions v1 v2;
    in
    if op == ">=" then
      cmp >= 0
    else if op == ">" then
      cmp > 0
    else if op == "<=" then
      cmp <= 0
    else if op == "<" then
      cmp < 0
    else if op == "==" || op == "=" then
      cmp == 0
    else if op == "!=" then
      cmp != 0
    else
      throw "nullkomma.r: unknown comparison operator `${op}`";

  # Validate dependency constraints against an attribute set of package versions ({ name = version; })
  validateConstraints =
    {
      dcf,
      fields,
      versions,
    }:
    let
      deps = depsOf dcf fields;
      errors = lib.filter (e: e != null) (
        map (
          dep:
          if dep.op != null && dep.version != null then
            let
              actual = versions.${dep.name} or null;
            in
            if actual == null then
              "nullkomma.r: no selected version for ${dep.name}"
            else if !matchVersion dep.op actual dep.version then
              "nullkomma.r: DESCRIPTION requires ${dep.name} (${dep.op} ${dep.version}); selected version is ${actual}. Add a pinned remote or choose a compatible package set."
            else
              null
          else
            null
        ) deps
      );
    in
    if errors != [ ] then throw (lib.concatStringsSep "\n" errors) else true;
}
