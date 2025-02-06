# treefmt.nix
{...}: {
  # Used to find the project root
  projectRootFile = ".git/config";
  # keep-sorted start
  programs.actionlint.enable = true;
  programs.alejandra.enable = true;
  programs.beautysh.enable = true;
  programs.black.enable = true;
  programs.cmake-format.enable = true;
  programs.deadnix.enable = true;
  programs.hclfmt.enable = true;
  programs.isort.enable = true;
  programs.jsonfmt.enable = true;
  programs.keep-sorted.enable = true;
  programs.mdformat.enable = true;
  programs.prettier.enable = true;
  programs.shellcheck.enable = true;
  programs.shfmt.enable = true;
  programs.sqlfluff.enable = true;
  programs.terraform.enable = true;
  programs.toml-sort.enable = true;
  programs.yamlfmt.enable = true;
  # keep-sorted end
}
