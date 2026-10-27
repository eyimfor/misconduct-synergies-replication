#!/bin/bash
# =============================================================================
# One-pass driver: foundational datasets -> every table and figure in the paper.
# CollectData/run_collect.sh builds the foundational datasets from raw/; run it first.
#
# Usage:
#     bash run_all.sh
#
# The script runs from wherever it sits. To run it from elsewhere, or to point
# it at a different interpreter, set PKG, PY, or STATA:
#     PKG=/path/to/replication_pipeline PY=python3 STATA=stata-mp bash run_all.sh
#
# Each step writes a log under logs/ and prints ok or FAIL; the run continues
# past a failure and lists every failed step at the end.
# =============================================================================
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PKG=${PKG:-$HERE}
PY=${PY:-python3}
STATA=${STATA:-stata-mp}
export PKG                       # _config.do and the python producers read it
L=$PKG/logs/driver
mkdir -p "$L" "$PKG/logs/build"
FAILED=()

RUNNERS=$PKG/_runners
BRR=$PKG/CreateTables/BrokerRegistrationRobustness

stata_step () {   # $1 = runner basename, $2 = log to grep
  local r=$1 lg=$2
  printf "  %-34s " "$r"
  ( cd "$RUNNERS" && "$STATA" -b do "$r.do" >/dev/null 2>&1 )
  local f="$PKG/logs/$lg.log"
  if [ ! -f "$f" ]; then echo "NO LOG"; FAILED+=("$r:nolog"); return; fi
  local e; e=$(grep -cE '^r\([0-9]+\);' "$f")
  local rc; rc=$(grep -oE 'RC_[A-Za-z0-9_]+ = [0-9]+' "$f" | awk '$3!=0' | head -3 | tr '\n' ' ')
  if [ "$e" -gt 0 ] || [ -n "$rc" ]; then echo "FAIL  r()=$e  $rc"; FAILED+=("$r"); else echo "ok"; fi
}

py_step () {      # $1 = label, rest = command
  local lab=$1; shift
  printf "  %-34s " "$lab"
  if "$@" > "$L/$lab.log" 2>&1; then echo "ok"; else echo "FAIL"; FAILED+=("$lab"); fi
}

echo "PKG = $PKG"
echo "=== 1. adviser employment, exam, and disclosure panels ==========="
stata_step 01_build_adviser_panels  build/01_build_adviser_panels
echo "=== 2. Form ADV controls, firm misconduct, AUM per employee, fines =="
stata_step 02_build_firm_controls  build/02_build_firm_controls
stata_step 03_build_firm_misconduct  build/03_build_firm_misconduct
echo "=== 3. merger list ==============================================="
stata_step 04_merger_list_entry        04_merger_list_entry
echo "=== 4. merger sample, ADV withdrawals, firm closure =============="
stata_step 05_merger_sample            05_merger_sample
stata_step 06_adv_withdrawals          06_adv_withdrawals
echo "=== 5. target/acquirer regressions, Figure 1, matching ==========="
stata_step 07_target_acquirer_regressions  07_target_acquirer_regressions
stata_step 08_figure_disclosures           08_figure_disclosures
stata_step 09_build_matching_pairs     09_build_matching_pairs
stata_step 10_matching_baseline            10_matching_baseline
stata_step 11_matching_time_window         11_matching_time_window
echo "=== 6. separations =============================================="
stata_step 12_separations              12_separations
echo "=== 7. post-merger misconduct, Figure 6, Table XI, appendix ======"
stata_step 13_post_merger_misconduct    13_post_merger_misconduct
stata_step 14_counterfactual_separation 14_counterfactual_separation
stata_step 15_misconduct_drop_employee  15_misconduct_drop_employee
stata_step 16_appendix_regressions     16_appendix_regressions
echo "=== 8. labor outcomes ============================================"
stata_step 17_labor_outcomes           17_labor_outcomes
echo "=== 9. broker registration robustness ============================"
printf "  %-34s " "broker registration 01-05"
( cd "$BRR" && "$STATA" -b do run_all.do >/dev/null 2>&1 )
# Judge the chain on the return codes that run_all.do logs for steps 01 through 05.
if [ ! -f "$BRR/logs/run_all.log" ] || grep -qE 'RC_BRR_0[1-5] = [1-9]' "$BRR/logs/run_all.log"; then
  echo "FAIL"; FAILED+=("broker_robustness"); else echo "ok"; fi
cp "$BRR/post_misc_regs_examqual.tex" "$PKG/2023/tables/" 2>/dev/null
echo "=== 10. figures and tables built in Python ======================="
cd "$PKG"
py_step figure2_all_pairs       env MPLBACKEND=Agg "$PY" "$PKG/CreateFigures/_0_figure2_all_pairs.py"
py_step figure2_within_state    env MPLBACKEND=Agg "$PY" "$PKG/CreateFigures/_0_figure2_within_state.py"
py_step figure3_matching_rank   env MPLBACKEND=Agg "$PY" "$PKG/CreateFigures/_0_figure3_matching_rank.py"
py_step figureA1_fines_per_year env MPLBACKEND=Agg "$PY" "$PKG/CreateFigures/_1_fines_per_year.py"
py_step summary_statistics_table env MPLBACKEND=Agg "$PY" "$PKG/CreateTables/_8_summary_statistics.py"
py_step tables7and8             env MPLBACKEND=Agg "$PY" "$PKG/CreateTables/_8_tables7and8.py"
py_step figure4_combined_firm   env MPLBACKEND=Agg "$PY" "$PKG/CreateFigures/_1_figure4_combined_disclosures.py"
py_step make_figure1            env MPLBACKEND=Agg "$PY" "$PKG/CreateFigures/_0_figure1_disclosures.py"
py_step frequent_acquirers      env MPLBACKEND=Agg "$PY" "$PKG/CreateTables/_8_frequent_acquirers.py"
# WORK holds the intermediate files; OUT is where the three panels are written. Without
# them the scripts write to fig_work/ under the current directory, so set both.
FIGA2_WORK=${FIGA2_WORK:-$PKG/figA2_work}
mkdir -p "$FIGA2_WORK"
py_step figA2_extract           env MPLBACKEND=Agg WORK="$FIGA2_WORK" OUT="$PKG/2023/figures" "$PY" "$PKG/CreateFigures/_2_figA2_extract_employment.py"
py_step figA2_metrics           env MPLBACKEND=Agg WORK="$FIGA2_WORK" OUT="$PKG/2023/figures" "$PY" "$PKG/CreateFigures/_2_figA2_compute_metrics.py"
py_step figA2_panels            env MPLBACKEND=Agg WORK="$FIGA2_WORK" OUT="$PKG/2023/figures" "$PY" "$PKG/CreateFigures/_2_figA2_panels.py"
# Figure A.3 is re-estimated from the built panels. run_figA3.py reads the package and
# writes everything under FIGA3_WORK (about 1.6 GB); _3_figA3_plot.py then reads the two
# JSON result files from that same scratch dir and writes the panels into 2023/figures.
FIGA3_WORK=${FIGA3_WORK:-$PKG/figA3_work}
mkdir -p "$FIGA3_WORK"
py_step figA3_estimate          env MPLBACKEND=Agg FIGA3_PKG="$PKG" FIGA3_WORK="$FIGA3_WORK" FIGA3_STATA="$STATA" "$PY" "$PKG/CreateFigures/figA3_estimation/run_figA3.py"
py_step figA3_plot              env MPLBACKEND=Agg WORK="$FIGA3_WORK" OUT="$PKG/2023/figures" "$PY" "$PKG/CreateFigures/_3_figA3_plot.py"
echo "=== 11. port fragments into the paper's layout =================="
# Snapshot the producer fragments first, then port out of the snapshot and into
# 2023/tables. Reading and writing one folder would overwrite the producer output
# with its own ported form, so a second run would have nothing correct to read.
rm -rf "$PKG/2023/tables_producer"; mkdir -p "$PKG/2023/tables_producer"
cp "$PKG"/2023/tables/*.tex "$PKG/2023/tables_producer/" 2>/dev/null
py_step port_tables       env TABLES="$PKG/2023/tables_producer" OUT="$PKG/2023/tables" "$PY" "$PKG/CreateTables/_9_port_tables.py"
py_step port_stats_tables env TABLES="$PKG/2023/tables_producer" OUT="$PKG/2023/tables" "$PY" "$PKG/CreateTables/_9_port_stats_tables.py"

echo "=== 12. exhibit accounting ======================================"
# The steps above report whether a SCRIPT ran. This reports whether the paper's
# EXHIBITS actually arrived. They are not the same thing: a producer can succeed
# and write outside the package, and the driver would still say ok.
# EXHIBITS.txt, in the package root, lists the 37 code-produced exhibits the paper uses.
missing=0; present=0
if [ ! -f "$PKG/EXHIBITS.txt" ]; then
  echo "  exhibit accounting                 FAIL  EXHIBITS.txt not found"
  FAILED+=("exhibit_accounting:nolist")
else
  while read -r rel; do
    [ -z "$rel" ] && continue
    case "$rel" in tables/*) f="$PKG/2023/tables/${rel#tables/}";; figures/*) f="$PKG/2023/figures/${rel#figures/}";; *) continue;; esac
    if [ -s "$f" ]; then present=$((present+1)); else
      echo "  MISSING  $rel"; missing=$((missing+1)); FAILED+=("exhibit:${rel##*/}")
    fi
  done < "$PKG/EXHIBITS.txt"
  total=$((present+missing))
  printf "  %-34s " "exhibit accounting"
  if [ "$missing" -eq 0 ]; then echo "ok  $present/$total"; else echo "FAIL  $present/$total"; fi
fi
echo
if [ ${#FAILED[@]} -eq 0 ]; then echo "ALL STEPS OK"; else printf "FAILED STEPS: %s\n" "${FAILED[*]}"; fi
echo "FINISHED $(date +%H:%M:%S)"
