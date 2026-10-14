let
  welcomeText = ''
    # Welcome to nullkomma

    Next steps:

    The template includes `.envrc` for automatic shell activation.

    1. `git add flake.nix .envrc` (flakes only see tracked files)
    2. `nix develop -c write-files` to write source-of-truth files (`.gitignore`, CI stubs, …)
    3. `nix develop -c generate-files` for Git-ignored editor settings generated from Nix
    4. `direnv allow` (or `nix develop`)
    5. `tasks` to list all tasks
  '';
in
{
  flake.templates = {
    default = {
      path = ../templates/default;
      description = "nullkomma project: devshell, treefmt, checks, CI";
      inherit welcomeText;
    };
  };
}
