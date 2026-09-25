#!/bin/bash
# Extracts one shard of a scrape archive with _0_onepass_extract.py.
# args: archive tag nshard shard
#   <archive> is a .tar.zst, streamed through `zstd` (keep zstd on PATH or set ZSTD).
#   The extractor's output goes to extract.log in the shard folder.
WORK=${WORK:-../collect_work}   # scratch space
PY=${PY:-python3}       # python interpreter
# .tar.zst archives are streamed through the `zstd` binary. Widen PATH to the
# usual conda/homebrew prefixes so a login shell that lacks them still resolves
# it; $ZSTD, if set, overrides the search entirely.
export PATH="$PATH:$HOME/anaconda3/bin:$HOME/opt/anaconda3/bin:$HOME/miniconda3/bin:/opt/homebrew/bin:/usr/local/bin"
export ZSTD
here=$(cd "$(dirname "$0")" && pwd)
EX=$here/_0_onepass_extract.py
archive=$1; tag=$2; n=$3; s=$4
d=$(printf "%s/temp/%s/%s_s%03d" "$WORK" "$tag" "$tag" "$s")
rm -rf "$d"; mkdir -p "$d"
$PY "$EX" "$archive" "$d" "$s" "$n" > "$d/extract.log" 2>&1 || echo "FAIL $tag $s (see $d/extract.log)"
