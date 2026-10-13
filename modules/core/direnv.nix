{
  flake.flakeModules.default = {
    perSystem.nullkomma.files.".envrc".text = ''
      # shellcheck shell=bash
      use flake
    '';
  };
}
