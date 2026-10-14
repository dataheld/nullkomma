{
  description = "A project with bats tests";

  inputs.nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      nullkomma.bats.enable = true;
      perSystem =
        { pkgs, ... }:
        {
          nullkomma.bats = {
            packages = [ pkgs.jq ];
            libraries = with pkgs.bats.libraries; [
              bats-assert
              bats-support
            ];
          };
        };
    };
}
