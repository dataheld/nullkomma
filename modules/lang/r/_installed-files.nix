# A watch path for the files that R CMD INSTALL installs, but help pages,
# and R/ and NAMESPACE, which reach processes through r-document-namespace's cascade.
{
  path = ".";
  include = [
    "DESCRIPTION"
    "LICENSE"
    "LICENCE"
    "NEWS"
    "NEWS.md"
  ]
  ++ map (dir: "${dir}/**") [
    "data"
    "demo"
    "exec"
    "inst"
    "src"
  ];
  # File names in `include` match at any depth; load_all compiles into src/.
  exclude = [
    "tests/**"
    "vignettes/**"
    "*.o"
    "*.so"
    "*.dll"
  ];
}
