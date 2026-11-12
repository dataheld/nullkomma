# Splices `nullkomma:<name>` marker sections into project-owned text: declared sections are
# replaced in place or appended, undeclared ones removed, everything else kept.
# A text without markers that equals the sections' plain content gets them marked.
# Variables: `sections`, space-separated `<name> <file>` pairs; `prefix` and `suffix` of new markers.
function block(name, line) {
  out = out prefix " nullkomma:" name ":start" suffix "\n"
  while ((getline line < file[name]) > 0) out = out line "\n"
  close(file[name])
  out = out prefix " nullkomma:" name ":end" suffix "\n"
}
function malformed() {
  print "Malformed nullkomma section markers in " FILENAME "; keep one complete start/end pair per section." > "/dev/stderr"
  failed = 1
  exit 1
}
BEGIN {
  count = split(sections, pair, " ")
  for (i = 1; i < count; i += 2) {
    name[++declared] = pair[i]
    file[pair[i]] = pair[i + 1]
    while ((getline line < pair[i + 1]) > 0) plain = plain line "\n"
    close(pair[i + 1])
    if (i + 2 < count) plain = plain "\n"
  }
}
{ text = text $0 "\n" }
match($0, /^[^[:space:]]+ nullkomma:[^:[:space:]]+:(start|end)( [^[:space:]]+)?$/) {
  marked = 1
  split($0, parts, ":")
  if (parts[3] ~ /^end/) {
    if (open != parts[2]) malformed()
    open = ""
  } else if (open != "" || parts[2] in seen) {
    malformed()
  } else {
    open = parts[2]
    seen[open] = 1
    if (open in file) block(open)
  }
  next
}
open == "" { out = out $0 "\n" }
END {
  if (failed) exit 1
  if (open != "") malformed()
  if (!marked && text == plain) out = ""
  for (i = 1; i <= declared; i++) {
    if (name[i] in seen) continue
    if (out != "" && out !~ /\n\n$/) out = out "\n"
    block(name[i])
  }
  printf "%s", out
}
