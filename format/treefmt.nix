# treefmt.nix
{pkgs, ...}: {
  # Used to find the project root
  projectRootFile = ".git/config";
  programs.alejandra.enable = true;
}
