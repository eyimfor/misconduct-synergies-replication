# ******************************************************************************
# Raw SEC Form ADV-W quarterly FOIA files -> all_withdrawals.csv
#
# One row per withdrawal filing. Read by CreateTables/build_adv_withdrawal_failures.do,
# which is how Table XII Panel B (firm closure) gets its closure dates.
#
# The file list is sorted so the appended row order is the same on every system.
# Malformed rows in the raw files are skipped (on_bad_lines="skip").
#
# usage: run with no arguments; RAW and PKG are read from the environment.
# ******************************************************************************

import os
import pandas as pd

# Input and scratch folders
RAW  = os.environ.get("RAW",  "../collect_work/raw_unpacked")           # the raw/ folder, unpacked
WORK = os.environ.get("WORK", "../collect_work")       # scratch space
in_folder  = RAW  + "/form_adv_w/adv_withdrawals"

# Output goes to $PKG/upstream_inputs; with PKG unset, to the scratch folder.
PKG  = os.environ.get("PKG", "")
out_folder = (PKG + "/upstream_inputs") if PKG else WORK + "/output"
os.makedirs(out_folder, exist_ok=True)

# Columns kept from each quarterly file
KEEP = ["CRD Number", "Full Legal Name", "Date Ceased", "Filing Date",
        "Reasons for Withdrawal"]

# List the quarterly files in sorted order, excluding any earlier output
files = sorted(f for f in os.listdir(in_folder) if f.endswith(".csv")
               and f != "all_withdrawals.csv")
print("ADV-W files:", len(files))

# Read each file, keep the columns and drop duplicate rows within the file
pieces = []
for name in files:
    data = pd.read_csv(os.path.join(in_folder, name), encoding="ISO-8859-1",
                       low_memory=False, dtype=str, on_bad_lines="skip")
    data = data.loc[:, KEEP].drop_duplicates()
    pieces.append(data)
    print(f"  {name:48s} {len(data):>8,}")

# Stack the files and write all_withdrawals.csv
out = pd.concat(pieces)
out.to_csv(os.path.join(out_folder, "all_withdrawals.csv"), index=False)
print("ROWS_OUT", len(out))
print("RUN_FINISHED=1")
