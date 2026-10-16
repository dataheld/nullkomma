let
  welcomeText = ''
    # Welcome to nullkomma

    1. `git add flake.nix .envrc` (flakes only see tracked files)
    2. `nix develop -c write-files` and `nix develop -c generate-files`
    3. `direnv allow` (or `nix develop`), then `tasks` to list tasks
  '';
in
{
  flake.templates = {
    default = {
      path = ../templates/default;
      description = "nullkomma project: devshell, treefmt, checks, CI";
      inherit welcomeText;
    };
    r = {
      path = ../templates/r;
      description = "R package: pak dependencies, formatting, language server and package checks";
      welcomeText = welcomeText + ''

        R projects are packages: add a DESCRIPTION, then run `nix run .#r-lock` before step 2.
      '';
    };
  };
}
