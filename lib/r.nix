# Pure helpers for R projects. Parsing DESCRIPTION is left to R itself
# (see `description-deps.R`), never reimplemented here.
{ lib }:
rec {
  defaultFields = [
    "Depends"
    "Imports"
    "LinkingTo"
    "Suggests"
  ];

  # Only a cheap presence test: DCF field names start a line, continuations are indented.
  hasPackageField = text: lib.any (l: lib.hasPrefix "Package:" l) (lib.splitString "\n" text);

  # nixpkgs mangles CRAN names: data.table -> data_table
  attrName = lib.replaceStrings [ "." ] [ "_" ];
}
