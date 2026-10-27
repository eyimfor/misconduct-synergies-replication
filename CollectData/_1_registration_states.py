# ******************************************************************************
# Adviser state registrations from the scrapes -> registration_states_all.csv
#
# One row per adviser, state and registration scope, with the registration date.
# Read by ma_employee_misconduct.do for Table A.10.
#
# Reads the registeredStates node of each adviser JSON in the 2020, 2022 and 2024
# scrapes, streamed in archive order from the raw/ .tar.zst archives, then stacks
# the three years and drops duplicate rows. The per-year files are written to disk
# and read back so that pandas assigns each column its type before the final write.
#
# usage: _1_registration_states.py
# ******************************************************************************

import csv, json, os, shutil, subprocess, sys, tarfile
from concurrent.futures import ProcessPoolExecutor
import pandas as pd

# Paths (overridable from the environment) and scrape years
RAW  = os.environ.get("RAW",  "../raw")    # the raw/ folder
WORK = os.environ.get("WORK", "../collect_work")   # scratch space
vintages = ["2020", "2022", "2024"]                                  # oldest first
temp_folder = WORK + "/temp/registration_states"

# Write where the pipeline reads. run_collect.sh exports PKG; with PKG unset the
# output goes to the scratch folder.
PKG  = os.environ.get("PKG", "")
out_folder = (PKG + "/SecIAPD/output") if PKG else WORK + "/local"

# Columns of the per-year and final files
columns = ["individualId", "state", "regScope", "regDate"]


def find_zstd():
    # Find the `zstd` binary (external, not a pip package): try $ZSTD, then PATH,
    # then the usual install prefixes, as in _0_onepass_extract.py
    exe = os.environ.get("ZSTD") or shutil.which("zstd")
    if exe:
        return exe
    for cand in ("/opt/homebrew/bin/zstd", "/usr/local/bin/zstd", "/usr/bin/zstd",
                 os.path.expanduser("~/anaconda3/bin/zstd"),
                 os.path.expanduser("~/opt/anaconda3/bin/zstd"),
                 os.path.expanduser("~/miniconda3/bin/zstd")):
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    sys.exit("registration_states: cannot find the `zstd` binary. Install zstd, put it "
             "on PATH, or set $ZSTD to its full path.")


def unwrap(data):
    # Scrapes are sometimes the raw adviser document and sometimes an
    # elasticsearch envelope around it
    if "hits" in data:
        try:
            return json.loads(data["hits"]["hits"][0]["_source"]["content"])
        except KeyError:
            return json.loads(data["hits"]["hits"][0]["_source"]["iacontent"])
    return data


def extract(year):
    # One sequential pass over the decompressed stream; nothing lands on disk
    archive = f"{RAW}/RawData{year}.tar.zst"
    out_path = f"{temp_folder}/registration_states{year}.csv"
    proc = subprocess.Popen([find_zstd(), "-dcq", archive], stdout=subprocess.PIPE)
    n_docs, n_failed = 0, 0
    with open(out_path, "w", newline="") as f, \
         tarfile.open(fileobj=proc.stdout, mode="r|") as tar:
        writer = csv.writer(f)
        writer.writerow(columns)
        for member in tar:
            if not member.isfile() or not member.name.endswith(".txt"):
                continue
            # A document that fails to parse, or lacks a field, is skipped from that
            # point on; rows already written for it are kept
            try:
                data = unwrap(json.load(tar.extractfile(member)))
                for state in data.get("registeredStates", []):
                    writer.writerow([data["basicInformation"]["individualId"] or "",
                                     state["state"] or "", state["regScope"] or "",
                                     state["regDate"] or ""])
                n_docs += 1
            except Exception:
                n_failed += 1
    proc.wait()
    return year, n_docs, n_failed


# The guard matters: macOS starts worker processes by re-importing this file
if __name__ == "__main__":
    # Create the scratch and output folders
    os.makedirs(temp_folder, exist_ok=True)
    os.makedirs(out_folder, exist_ok=True)

    # The three archives are independent, so read them side by side
    with ProcessPoolExecutor(max_workers=len(vintages)) as pool:
        for year, n_docs, n_failed in pool.map(extract, vintages):
            print(f"RawData{year}: {n_docs} documents read, {n_failed} skipped")

    # Stack the scrape years, oldest first, drop the rows they share, and write
    # registration_states_all.csv
    dfs = [pd.read_csv(f"{temp_folder}/registration_states{y}.csv", usecols=columns)
           for y in vintages]
    df_final = pd.concat(dfs, ignore_index=True).drop_duplicates()
    df_final.columns = columns
    df_final.to_csv(out_folder + "/registration_states_all.csv", index=False)
    print("ROWS_OUT", len(df_final))
    print("RUN_FINISHED=1")
