{
  flake.templates.default = {
    path = ../templates/default;
    description = "nullkomma project: devshell, treefmt, checks, CI";
    welcomeText = ''
      # Welcome to nullkomma

      1. `git add flake.nix` (flakes only see tracked files)
      2. `nix develop -c nk write-files` and `nix develop -c nk generate-files`
      3. `direnv allow` (or `nix develop`), then `nk` to list tasks
      4. Configure plugins in `nix/`, e.g.
         `nix eval --raw --inputs-from . nullkomma#lib.configs.r > nix/r.nix`
    '';
  };
}
