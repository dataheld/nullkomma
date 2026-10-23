{
  pkgs,
  lib,
  brand,
  privacyHref ? null,
}:
let
  branded = brand != null;
  adapter = dir: {
    theme = {
      light = [
        "default"
        "brand"
      ];
      dark = [
        "default"
        "brand"
        "${dir}/dark.scss"
      ];
    };
    respect-user-color-scheme = true;
    filters = [ "${dir}/landmarks.lua" ];
  };
  metadata = lib.optionalAttrs branded {
    website.navbar.background = "primary";
    format.html = adapter "_extensions/nullkomma-brand";
  };
  home = {
    href = "index.qmd";
    text = "Home";
  };
  docs = lib.recursiveUpdate {
    project.type = "website";
    website = {
      repo-actions = [
        "edit"
        "source"
        "issue"
      ];
      bread-crumbs = true;
      page-navigation = true;
      search = {
        location = "navbar";
        type = "overlay";
      };
      back-to-top-navigation = true;
      navbar = {
        pinned = true;
        left = [ home ];
      };
      sidebar = {
        style = "docked";
        contents = [ home ];
      };
    };
    format.html = {
      toc = true;
      toc-depth = 3;
      code-copy = true;
      code-link = true;
      css = [ "docs.css" ];
      filters = [ "../nullkomma-brand/landmarks.lua" ];
    };
  } (lib.optionalAttrs branded (metadata // { format.html = adapter "../nullkomma-brand"; }));
in
pkgs.runCommand "site-brand" { nativeBuildInputs = [ pkgs.pandoc ]; } ''
  pandoc lua ${./brand.lua} \
    ${lib.escapeShellArg (if branded then "${brand.lib.brand}" else "")} \
    ${lib.escapeShellArg (if privacyHref == null then "" else privacyHref)} \
    ${lib.escapeShellArg (builtins.toJSON metadata)} \
    ${lib.escapeShellArg (builtins.toJSON docs)} \
    "$out"
  cp ${../modules/lang/_quarto/dark.scss} "$out/dark.scss"
  cp ${../modules/lang/_quarto/landmarks.lua} "$out/landmarks.lua"
''
