# Pure helpers for R projects; no packages, no IFD.
{ lib }:
rec {
  # Packages that ship with R itself and are therefore not in `rPackages`.
  basePackages = [
    "R"
    "base"
    "compiler"
    "datasets"
    "grDevices"
    "graphics"
    "grid"
    "methods"
    "parallel"
    "splines"
    "stats"
    "stats4"
    "tcltk"
    "tools"
    "utils"
  ];

  # Minimal Debian Control File (DCF) parser for R DESCRIPTION files.
  parseDCF =
    text:
    let
      lines = lib.filter (l: lib.trim l != "") (lib.splitString "\n" text);
      folded = lib.foldl' (
        acc: l:
        if acc != [ ] && builtins.match "[ \t].*" l != null then
          lib.init acc ++ [ (lib.last acc + " " + lib.trim l) ]
        else
          acc ++ [ l ]
      ) [ ] lines;
      field =
        l:
        let
          m = builtins.match "([^: \t]+):[ \t]*(.*)" l;
        in
        if m == null then
          throw "nullkomma: cannot parse DCF line `${l}`"
        else
          lib.nameValuePair (lib.elemAt m 0) (lib.trim (lib.elemAt m 1));
    in
    lib.listToAttrs (map field folded);

  # "foo (>= 1.0), bar,\n baz" -> [ "foo" "bar" "baz" ], minus base packages.
  depNames =
    s:
    lib.filter (n: n != "" && !lib.elem n basePackages) (
      map (d: lib.trim (lib.head (lib.splitString "(" d))) (lib.splitString "," s)
    );

  defaultFields = [
    "Depends"
    "Imports"
    "LinkingTo"
    "Suggests"
  ];

  depsFromDescription =
    {
      path,
      fields ? defaultFields,
    }:
    let
      d = parseDCF (builtins.readFile path);
    in
    lib.unique (lib.concatMap (f: depNames (d.${f} or "")) fields);

  # nixpkgs mangles CRAN names: data.table -> data_table
  attrName = lib.replaceStrings [ "." ] [ "_" ];
}
