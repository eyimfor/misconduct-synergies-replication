# ******************************************************************************
# Combines the current and previous BrokerCheck and IAPD employment extracts into
# employmentdataall_2024.csv, the adviser-firm registration spells that the adviser
# panels are built from. Open spells are closed at the snapshot date, 31 March 2024.
# ******************************************************************************

import os
import pandas as pd

# Scratch space, overridable from the environment
WORK = os.environ.get("WORK", "../collect_work")   # scratch space

# Snapshot date and input folder
asof_date  = "2024-03-31"
in_folder  = WORK + "/combined"

# Write where the pipeline reads (BuildPanels reads ../SecIAPD/output); with PKG unset
# this falls back to WORK/local.
PKG = os.environ.get("PKG", "")
out_folder = (PKG + "/SecIAPD/output") if PKG else WORK + "/local"
os.makedirs(out_folder, exist_ok=True)

# The sixteen employment extracts: the 2020, 2022 and 2024 scrapes, current and
# previous employment, BrokerCheck and IAPD, plus the 2024 top-up files
# (*missing2024.csv) for records the main 2024 scrape did not return.
#
# The panel is the union of the three scrapes. BrokerCheck drops anyone unregistered
# for ten years, so the 2024 scrape alone loses 282,911 advisers whose registrations
# ended in 2009-2014 (11.5% of spells). Files are listed oldest first.
file_paths = [
    in_folder + "/currentemploymentdata2020.csv",
    in_folder + "/previous_employmentdata2020.csv",
    in_folder + "/currentia_employmentdata2020.csv",
    in_folder + "/previousia_employmentdata2020.csv",
    in_folder + "/currentemploymentdata2022.csv",
    in_folder + "/previous_employmentdata2022.csv",
    in_folder + "/currentia_employmentdata2022.csv",
    in_folder + "/previousia_employmentdata2022.csv",
    in_folder + "/currentemploymentdata2024.csv",
    in_folder + "/currentemploymentdatamissing2024.csv",
    in_folder + "/previous_employmentdata2024.csv",
    in_folder + "/previous_employmentdatamissing2024.csv",
    in_folder + "/currentia_employmentdata2024.csv",
    in_folder + "/currentia_employmentdatamissing2024.csv",
    in_folder + "/previousia_employmentdata2024.csv",
    in_folder + "/previousia_employmentdatamissing2024.csv",
]

# Read each extract and keep the identifying columns
dfs = []
for file_path in file_paths:
    df = pd.read_csv(file_path, encoding="iso-8859-1", low_memory=False)
    # Drop rows with no individual, no firm, or no start date
    required_cols = ["individualId", "Firm ID", "Registration Begin Date"]
    df = df[~df[required_cols].isnull().any(axis=1)]
    # Keep the identifying columns plus the end date where the extract has one
    cols_to_use = required_cols + ["City", "State", "Zip Code"]
    if "Registration End Date" in df.columns:
        cols_to_use.append("Registration End Date")
    df = df[cols_to_use]
    # Tag which scrape the rows came from
    file_name = os.path.basename(file_path)
    df["scrape_year"] = int("".join(filter(str.isdigit, file_name[-8:-4])))
    print(file_name, len(df))
    dfs.append(df)

# Stack the extracts
df_concat = pd.concat(dfs, ignore_index=True).drop_duplicates()

# Keep spells with a usable start date
df_concat["Registration Begin Date"] = pd.to_datetime(df_concat["Registration Begin Date"], errors="coerce")
df_concat = df_concat[df_concat["Registration Begin Date"].notna()]

# Keep spells with a usable firm id
df_concat["Firm ID"] = pd.to_numeric(df_concat["Firm ID"], errors="coerce")
df_concat = df_concat.dropna(subset=["Firm ID"])
df_concat["Firm ID"] = df_concat["Firm ID"].astype(int)

# Flag the spells that were still open at the scrape, then close them at the
# snapshot date (a fixed date, so reruns give the same file)
df_concat["is_temporary_end_date"] = df_concat["Registration End Date"].isna().astype(int)
df_concat["Registration End Date"] = pd.to_datetime(df_concat["Registration End Date"], errors="coerce")
df_concat["Registration End Date"] = df_concat["Registration End Date"].fillna(pd.to_datetime(asof_date))

# One row per adviser-firm-spell-office
df_final = df_concat[["individualId", "Firm ID", "Registration Begin Date", "Registration End Date",
                      "City", "State", "Zip Code", "is_temporary_end_date"]]
df_final = df_final.drop_duplicates()
df_final = df_final[df_final["Registration End Date"].notna()]

# Prefer a real end date over the stamped one, then the earliest end date
df_final = df_final.sort_values(["individualId", "Firm ID", "Registration Begin Date", "City", "State",
                                 "Zip Code", "is_temporary_end_date", "Registration End Date"])
df_final = df_final.groupby(["individualId", "Firm ID", "Registration Begin Date", "City", "State", "Zip Code"]).agg({
    "Registration End Date": "first",
    "is_temporary_end_date": "first",
}).reset_index()

# The output carries these 7 columns in this order, without the open-spell flag
df_final = df_final[["individualId", "Firm ID", "Registration Begin Date", "Registration End Date",
                     "City", "State", "Zip Code"]]

# Write employmentdataall_2024.csv
df_final.to_csv(out_folder + "/employmentdataall_2024.csv", index=False)
print("ROWS_OUT", len(df_final))
print("RUN_FINISHED=1")
