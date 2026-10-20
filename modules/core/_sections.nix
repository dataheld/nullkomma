# Splices `nullkomma:<name>` marker sections into project-owned text: declared sections are
# replaced in place or appended, undeclared ones removed, everything else kept.
{ lib }:
{
  commentPrefix,
  commentSuffix,
  sections,
}:
text:
let
  marker = kind: name: "${commentPrefix} nullkomma:${name}:${kind}${commentSuffix}";
  block =
    name:
    [ (marker "start" name) ]
    ++ lib.splitString "\n" (lib.removeSuffix "\n" sections.${name})
    ++ [ (marker "end" name) ];
  pattern = "${lib.escapeRegex commentPrefix} nullkomma:([^:]+):(start|end)${lib.escapeRegex commentSuffix}";
  malformed = throw "Malformed nullkomma section markers; keep one complete start/end pair per section.";
  step =
    acc: line:
    let
      m = builtins.match pattern line;
    in
    if acc.open != null then
      if m == null then
        acc
      else if
        m == [
          acc.open
          "end"
        ]
      then
        acc // { open = null; }
      else
        malformed
    else if m == null then
      acc // { lines = acc.lines ++ [ line ]; }
    else if lib.elemAt m 1 == "end" || lib.elem (lib.head m) acc.seen then
      malformed
    else
      {
        open = lib.head m;
        seen = acc.seen ++ [ (lib.head m) ];
        lines = acc.lines ++ lib.optionals (sections ? ${lib.head m}) (block (lib.head m));
      };
  result = lib.foldl' step {
    open = null;
    seen = [ ];
    lines = [ ];
  } (lib.splitString "\n" text);
  body = lib.concatStringsSep "\n" result.lines;
  missing = lib.subtractLists result.seen (lib.attrNames sections);
  separator =
    if body == "" || lib.hasSuffix "\n\n" body then
      ""
    else if lib.hasSuffix "\n" body then
      "\n"
    else
      "\n\n";
in
if result.open != null then
  malformed
else if missing == [ ] then
  body
else
  body + separator + lib.concatMapStringsSep "\n" (name: lib.concatLines (block name)) missing
