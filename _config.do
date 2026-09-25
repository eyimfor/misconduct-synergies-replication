*******************************************************************************************************
/* Sets the global $PKG (the package root) and the three ado paths every runner needs.

   Resolution order -- the first candidate that actually contains the package wins:
     1. the PKG environment variable, if it is set
     2. ".." -- the package root as seen from <PKG>/_runners, which is the directory the
        runners are executed from. An unpacked package therefore needs no edits at all.
     3. "."  -- the package root itself, if you run a runner from there
     4. any machine paths you add to the list below; the first one that exists wins.

   A candidate counts only if it holds 2023/data/input/new_mergers_raw.csv, so a wrong
   guess is never silently accepted. Relative candidates are resolved to an absolute path
   before being stored, because the runners cd into $PKG/2023 after reading this file. */
*******************************************************************************************************
global PKG ""

local envpkg : environment PKG
if `"`envpkg'"' != "" {
    cap confirm file `"`envpkg'/2023/data/input/new_mergers_raw.csv"'
    if !_rc global PKG `"`envpkg'"'
}

foreach c in ///
    ".." ///                                                       unpacked package: <PKG>/_runners -> <PKG>
    "." {                                                          // unpacked package: run from <PKG>
    if "$PKG" == "" {
        cap confirm file "`c'/2023/data/input/new_mergers_raw.csv"
        if !_rc {
            * store the absolute path: "." and ".." stop meaning the root once a runner cd's away
            local cwd_before "`c(pwd)'"
            qui cd "`c'"
            global PKG "`c(pwd)'"
            qui cd "`cwd_before'"
        }
    }
}

if "$PKG" == "" {
    display as error "Cannot locate the package root."
    display as error "Set the PKG environment variable, or add your path to the list in _config.do."
    exit 601
}
display "PKG = $PKG"

* the package's three ado folders
sysdir set PLUS     "$PKG/environment/ado_plus"
sysdir set PERSONAL "$PKG/environment/ado_personal"
adopath ++          "$PKG/environment/ado_shim"
