{ lib }:
rec {
  nonNixDocumentation = builtins.readFile ../modules/lang/r-non-nix/_assets/development.md;
  withNonNixDocumentation =
    text:
    let
      start = "<!-- nullkomma:r-development:start -->";
      end = "<!-- nullkomma:r-development:end -->";
      section = "${start}\n${nonNixDocumentation}${end}\n";
      parts = lib.splitString start text;
      rest = if lib.length parts == 2 then lib.splitString end (lib.last parts) else [ ];
    in
    if lib.length parts == 2 && lib.length rest == 2 then
      lib.head parts + section + lib.removePrefix "\n" (lib.last rest)
    else if lib.length parts != 1 || lib.hasInfix end text then
      throw "nullkomma.r-non-nix: malformed R development markers in README.md; keep one complete start/end pair."
    else if lib.hasInfix "\n## Development\n" ("\n" + text) then
      lib.removePrefix "\n" (
        lib.replaceStrings [ "\n## Development\n" ] [ "\n## Development\n\n${section}" ] ("\n" + text)
      )
    else
      text + "\n## Development\n\n${section}";
}
