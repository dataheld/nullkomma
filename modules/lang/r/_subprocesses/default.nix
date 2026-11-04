# `r-contain <command>` runs R so that the subprocesses processx starts stop with it; see README.md.
{
  stdenv,
  util-linux,
  writeShellApplication,
}:
let
  signals =
    name:
    writeShellApplication {
      inherit name;
      text = builtins.readFile ./signals.sh;
    };
in
if stdenv.hostPlatform.isLinux then
  writeShellApplication {
    name = "r-contain";
    runtimeInputs = [
      util-linux
      (signals "r-contain-signals")
    ];
    text = builtins.readFile ./linux.sh;
  }
else
  signals "r-contain"
