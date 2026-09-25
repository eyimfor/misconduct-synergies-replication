# Extracts adviser-firm-year employment rows (b_crd_number, crd_number, year) for the firms in
# merger_sample and adviser_event_panel, and writes emp_extract.parquet for the appendix figures.
import pandas as pd, numpy as np, time
import os

# Package root and scratch folder
PKG  = os.environ.get("PKG",  ".")             # package root
WORK = os.environ.get("WORK", "fig_work") # scratch space
os.makedirs(WORK, exist_ok=True)

# Firms to keep: every target and acquirer in the merger sample and the event panel
ms = pd.read_stata(PKG + "/2023/data/output/" + "merger_sample.dta")
md = pd.read_stata(PKG + "/2023/data/output/" + "adviser_event_panel.dta")
keep = set(ms.target_crd.astype(int)) | set(ms.acquirercrds.astype(int)) \
     | set(md.target_crd.astype(int)) | set(md.acquirer_crd.astype(int))
print("firms to keep:", len(keep), flush=True)
keep_arr = np.array(sorted(keep), dtype=np.int64)

# Read the adviser-firm-year file in chunks, keeping rows for those firms
t0=time.time(); parts=[]; n=0
it = pd.read_stata(PKG + "/2023/data/output/" + "adviser_firm_year.dta",
                   columns=["b_crd_number","crd_number","year"], chunksize=2_000_000)
for i,ch in enumerate(it):
    n += len(ch)
    ch = ch[ch.crd_number.isin(keep)]
    if len(ch): parts.append(ch)

# Combine, drop duplicate rows and write the extract
emp = pd.concat(parts, ignore_index=True)
emp["year"] = emp["year"].astype("int16")
emp = emp.drop_duplicates()
emp.to_parquet(WORK + "/emp_extract.parquet", index=False)
print("DONE", emp.shape, emp.year.min(), emp.year.max(), f"{time.time()-t0:.0f}s", flush=True)
