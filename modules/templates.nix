let
  welcomeText = ''
    # Welcome to nullkomma

    Next steps:

    1. `git add flake.nix` (flakes only see tracked files)
    2. `nix run .#write-files` to initialize `.gitignore`, `.envrc`, CI stubs, …
    3. `direnv allow` (or `nix develop`)
    4. `nix run` to list all tasks
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
