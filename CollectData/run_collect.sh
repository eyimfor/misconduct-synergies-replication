#!/bin/bash
# ******************************************************************************
# raw/ -> the foundational files run_all.sh starts from. Run once, before run_all.sh.
#   PKG   package root                      (default: the folder above this script)
#   RAW   the raw/ folder of .tar.zst files  (default: $PKG/../raw)
#   WORK  scratch space, about 15 GB         (default: $PKG/../collect_work)
#   PY    python interpreter                 (default: python3)
# Needs zstd on PATH. About 12 minutes: the four scrape archives are read in
# parallel, one shard each, because a .tar.zst keeps archive order only with a
# single shard (see ORDERING in _0_onepass_extract.py).
# Writes SecIAPD/output/ (scrape extracts), 2023/data/input/ (Form ADV) and
# upstream_inputs/ (Form ADV-W), which is where BuildPanels reads them.
# ******************************************************************************
set -e
here=$(cd "$(dirname "$0")" && pwd)
export PKG=${PKG:-$(dirname "$here")}
export RAW=${RAW:-$(dirname "$PKG")/raw}
export WORK=${WORK:-$(dirname "$PKG")/collect_work}
export PY=${PY:-python3}
export PATH="$PATH:$HOME/anaconda3/bin:$HOME/opt/anaconda3/bin:$HOME/miniconda3/bin:/opt/homebrew/bin:/usr/local/bin"
ZSTD=${ZSTD:-$(command -v zstd)} || { echo "zstd not found: install it or set ZSTD"; exit 1; }
export ZSTD
mkdir -p "$WORK/logs" "$PKG/SecIAPD/output" "$PKG/2023/data/input" "$PKG/upstream_inputs"

step() { name=$1; shift; echo "=== $name"
         "$@" > "$WORK/logs/$name.log" 2>&1 || { echo "FAILED: see $WORK/logs/$name.log"; exit 1; }; }

# 1. scrapes -> one set of extracts per archive
echo "=== extract scrapes"
for spec in "RawData2020 raw2020" "RawData2022 raw2022" "RawData2024 raw2024" "MissingJsons2024 miss2024"; do
    set -- $spec
    bash "$here/_0_shard_one.sh" "$RAW/$1.tar.zst" "$2" 1 0 > "$WORK/logs/extract_$2.log" 2>&1 &
done
wait
if grep -q FAIL "$WORK"/logs/extract_*.log; then echo "FAILED: see $WORK/logs/extract_*.log"; exit 1; fi

# 2. extracts -> the foundational scrape files
step assemble_extracts   "$PY" "$here/_1_assemble_extracts.py"
step combine_employment  "$PY" "$here/_1_combine_employment.py"
step combine_exams       "$PY" "$here/_1_combine_exams.py"
step consolidate_disc    "$PY" "$here/_1_consolidate_disclosures.py"
step registration_states "$PY" "$here/_1_registration_states.py"

# 3. Form ADV and ADV-W; these scripts read the archives unpacked
echo "=== unpack Form ADV archives"
mkdir -p "$WORK/raw_unpacked"
for a in form_adv_complete form_adv_w; do
    "$ZSTD" -dc "$RAW/$a.tar.zst" | tar -x -C "$WORK/raw_unpacked"
done
RAW="$WORK/raw_unpacked" step adv_controls          "$PY" "$here/_2_adv_controls.py"
RAW="$WORK/raw_unpacked" step adv_filing_dates      "$PY" "$here/_2_adv_filing_dates.py"
RAW="$WORK/raw_unpacked" step adv_withdrawals       "$PY" "$here/_2_adv_withdrawals.py"
echo "=== done: foundational files are in place for run_all.sh"
