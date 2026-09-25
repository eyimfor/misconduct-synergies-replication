# ******************************************************************************
# Consolidates the per-type disclosure files into SecIAPD/output/disclosures_2024.csv,
# the disclosure input to BuildPanels.
#
# Uses two functions from disclosure_extractors.py on the extracted files:
#   remove_duplicates_and_save  dedup each per-type file in place
#   consolidate_data            stack the types into 5 columns
# ******************************************************************************

import os, sys, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from disclosure_extractors import remove_duplicates_and_save, consolidate_data

# Input and scratch folders
WORK = os.environ.get("WORK", "../collect_work")   # scratch space
in_base = WORK + "/combined"
work    = WORK + "/temp_disc"

# Write where the pipeline reads (BuildPanels reads ../SecIAPD/output); with PKG unset
# this falls back to WORK/local.
PKG = os.environ.get("PKG", "")
out = (PKG + "/SecIAPD/output") if PKG else WORK + "/local"
os.makedirs(out, exist_ok=True)

# Gather the 2024 per-type files into one folder, appending the missing-JSON rows to
# their matching type
os.makedirs(work, exist_ok=True)
for name in sorted(os.listdir(in_base + "/disclosures_raw2024")):
    dst = os.path.join(work, name)
    shutil.copyfile(os.path.join(in_base, "disclosures_raw2024", name), dst)
    src2 = os.path.join(in_base, "disclosures_miss2024", name)
    if os.path.exists(src2):
        with open(dst, "a", encoding="utf-8", errors="replace") as w, \
             open(src2, encoding="utf-8", errors="replace") as r:
            r.readline()
            for line in r:
                w.write(line)

# Append the 2020 and 2022 rows, skipping each file's header
for z in ("raw2020", "raw2022"):
    d = f"{in_base}/disclosures_{z}"
    if not os.path.isdir(d):
        continue
    for name in sorted(os.listdir(d)):
        dst = os.path.join(work, name)
        with open(dst, "a", encoding="utf-8", errors="replace") as w, \
             open(os.path.join(d, name), encoding="utf-8", errors="replace") as r:
            r.readline()
            for line in r:
                w.write(line)
    print("appended", z)

# Deduplicate each per-type file, stack the types and write the CSV
remove_duplicates_and_save(work)
final_df = consolidate_data(work)
final_df.to_csv(out + "/disclosures_2024.csv", index=False)
print("ROWS_OUT", len(final_df))
print("COLUMNS", list(final_df.columns))
print("RUN_FINISHED=1")
