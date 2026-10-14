let
  welcomeText = ''
    # Welcome to nullkomma

    Next steps:

    The template includes `.envrc` for automatic shell activation.

    1. `git add flake.nix .envrc` (flakes only see tracked files)
    2. `nix run .#write-files` to initialize shared files (`.gitignore`, CI stubs, …)
    3. `nix run .#generate-files` for ignored, Nix-owned editor settings
    4. `direnv allow` (or `nix develop`)
    5. `nix run` to list all tasks
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
