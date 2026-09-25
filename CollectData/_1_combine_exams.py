# ******************************************************************************
# Combines the exam extracts from the 2020, 2022 and 2024 scrapes into exams_all2024.csv.
# As with the employment spells, the file is the union of the scrapes: a single scrape
# loses advisers who have been unregistered long enough to drop out of BrokerCheck.
# ******************************************************************************

# Imports
import os
import pandas as pd

# Input folder, and the output folder the pipeline reads (BuildPanels reads
# ../SecIAPD/output); with PKG unset this falls back to WORK/local
WORK = os.environ.get("WORK", "../collect_work")   # scratch space
in_folder  = WORK + "/combined"
PKG = os.environ.get("PKG", "")
out_folder = (PKG + "/SecIAPD/output") if PKG else WORK + "/local"
os.makedirs(out_folder, exist_ok=True)

# Exam extract files to combine: one per scrape, plus the 2024 missing-exams file
exam_files = {
    "exams2020":         in_folder + "/exams_raw2020.csv",
    "exams2022":         in_folder + "/exams_raw2022.csv",
    "exams2024":         in_folder + "/exams_raw2024.csv",
    "examsmissing2024":  in_folder + "/exams_miss2024.csv",
}

# Read each scrape
dataframes = {}
for name, file_path in exam_files.items():
    dataframes[name] = pd.read_csv(file_path, low_memory=False)
    print(name, len(dataframes[name]))

# Stack the scrapes and drop the rows they share
exams_all = pd.concat(dataframes.values()).drop_duplicates()

# Write the combined file
exams_all.to_csv(out_folder + "/exams_all2024.csv", index=False)
print("ROWS_OUT", len(exams_all))
print("RUN_FINISHED=1")
