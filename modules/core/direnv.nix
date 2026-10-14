{
  flake.plugins.base = {
    perSystem.nullkomma.files.".envrc".text = ''
      # shellcheck shell=bash
      use flake
    '';
  };
}
