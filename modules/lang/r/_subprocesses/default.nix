# `r-contain <command>` runs R so that the subprocesses processx starts stop with it; see README.md.
{
  lib,
  stdenv,
  util-linux,
  writeShellApplication,
}:
writeShellApplication {
  name = "r-contain";
  runtimeInputs = lib.optional stdenv.hostPlatform.isLinux util-linux;
  text = builtins.readFile (if stdenv.hostPlatform.isDarwin then ./darwin.sh else ./linux.sh);
}
