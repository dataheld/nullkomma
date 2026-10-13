{
  flake.flakeModules.default = {
    perSystem.nullkomma.files.".envrc".text = ''
      use flake
    '';
  };
}
