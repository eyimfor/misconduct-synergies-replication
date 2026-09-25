# ******************************************************************************
# Raw Form ADV bulk -> fiscal_month2023.dta
#
# fiscal_month2023.dta : one row per filing, with its fiscal year-end month (3B)
#
# Together with all_controls_2023.csv this is what build_fiscal_year_filings.do reads
# to put each filing in a fiscal year. The file list is sorted, because os.listdir
# is unordered on Linux.
# ******************************************************************************

import os
import pandas as pd

# Input and output folders
RAW  = os.environ.get("RAW",  "../collect_work/raw_unpacked")           # the raw/ folder, unpacked
WORK = os.environ.get("WORK", "../collect_work")       # scratch space
adv_folder = RAW  + "/form_adv_complete/ria2023_subset"

# Write where the pipeline reads. run_collect.sh exports PKG; with PKG unset the output
# goes to WORK/output.
PKG  = os.environ.get("PKG", "")
out_folder = (PKG + "/2023/data/input") if PKG else WORK + "/output"
os.makedirs(out_folder, exist_ok=True)


# ---- filing id -> fiscal year-end month, from the Base B files ---------------

# List the Base B files in sorted order
base_b_files = sorted(f for f in os.listdir(adv_folder) if "_Base_B_" in f)
print("base-B files:", len(base_b_files))

# Read the filing id and fiscal year-end month (3B) from each file
pieces = []
for file in base_b_files:
    data = pd.read_csv(os.path.join(adv_folder, file), encoding="ISO-8859-1",
                       low_memory=False, dtype=str)
    data = data[['FilingID', '3B']]
    # keep the source file name
    data['file'] = file
    pieces.append(data)
    print(file, len(data))

# Stack the files and name the month column
fiscal_month = pd.concat(pieces, ignore_index=True)
fiscal_month.rename(columns={'3B': 'Month_Fiscal_Year'}, inplace=True)

# The do-files read these names in lower case with underscores
fiscal_month.columns = (fiscal_month.columns.str.strip().str.lower()
                        .str.replace(' ', '_').str.replace('#', '').str.replace(')', ''))

# Write with the index; build_fiscal_year_filings.do reads the result
fiscal_month.to_stata(out_folder + "/fiscal_month2023.dta")
print("FISCALMONTH_ROWS", len(fiscal_month))
print("RUN_FINISHED=1")
