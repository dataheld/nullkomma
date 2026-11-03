# Each plugin's options as a module for `nix/<plugin>.nix`: enabled, the rest commented out at their defaults.
lib: plugins: options:
let
  docs = lib.filter (
    o:
    o.visible
    && !o.internal
    && !o.readOnly
    && o ? default
    && !lib.any (lib.hasInfix "<") o.loc
    && !lib.elem "*" o.loc
  ) (lib.optionAttrSetToDocList options);
  loc = o: lib.remove "perSystem" o.loc;
  byPlugin = lib.groupBy (o: lib.elemAt (loc o) 1) (
    lib.filter (o: lib.head (loc o) == "nullkomma" && lib.length (loc o) > 2) docs
  );
  comment = lib.replaceStrings [ "\n" ] [ "\n  # " ];
  wrap =
    text:
    lib.foldl' (
      lines: word:
      let
        last = lib.last lines;
      in
      if last == "" then
        [ word ]
      else if lib.stringLength last + lib.stringLength word >= 76 then
        lines ++ [ word ]
      else
        lib.init lines ++ [ "${last} ${word}" ]
    ) [ "" ] (lib.filter (w: w != "") (lib.splitString " " (lib.replaceStrings [ "\n" ] [ " " ] text)));
  isEnable = o: lib.length (loc o) == 3 && lib.last o.loc == "enable";
  render =
    o:
    let
      prose = o.default._type == "literalMD";
    in
    lib.concatMapStrings (line: "  # ${line}\n") (
      wrap ("${o.description or ""}" + lib.optionalString prose " Default: ${o.default.text}.")
    )
    + (
      if isEnable o then
        "  ${o.name} = true;\n"
      else
        "  # ${o.name} = ${if prose then "…" else comment o.default.text};\n"
    );
in
lib.genAttrs plugins (
  p:
  let
    opts = byPlugin.${p};
  in
  "{\n${lib.concatMapStringsSep "\n" render (lib.filter isEnable opts ++ lib.filter (o: !isEnable o) opts)}}\n"
)
