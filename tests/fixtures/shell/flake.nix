{
  description = "A project with bats tests";

  inputs = {
    nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";
    nixpkgs.follows = "nullkomma/nixpkgs";
  };

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      perSystem =
        { pkgs, ... }:
        {
          nullkomma.shell.bats = {
            packages = [ pkgs.jq ];
            libraries = with pkgs.bats.libraries; [
              bats-assert
              bats-support
            ];
          };
        };
    };
}
