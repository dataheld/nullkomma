{
  flake.templates.default = {
    path = ../templates/default;
    description = "nullkomma project: devshell, treefmt, checks, CI";
    welcomeText = ''
      # Welcome to nullkomma

      Continue with <https://github.com/dataheld/nullkomma#adding-nullkomma-to-a-project>.
    '';
  };
}
