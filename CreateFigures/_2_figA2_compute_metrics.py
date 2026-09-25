"""Deal-level adviser metrics for Appendix Figure A.2: the share of target advisers who
move to the acquirer, and target and combined headcount in event years -3 to +3, for
actual mergers and for the pseudo pairs of the Table IX estimation frame.
Writes figA_deal_metrics.csv, which Figure A.2 plots, and figA_pseudo_metrics.csv, a
diagnostic that does not enter the figure. Both go to $WORK."""
import pandas as pd, numpy as np, json
import os

# Paths, overridable from the environment
PKG  = os.environ.get("PKG",  ".")             # package root
WORK = os.environ.get("WORK", "fig_work") # scratch space
O = WORK

# Adviser employment records, 2007-2024
emp = pd.read_parquet(O + "/emp_extract.parquet")
emp = emp[(emp.year >= 2007) & (emp.year <= 2024)]

# Adviser sets by (firm, year); S returns the set, empty if the firm has none
g = emp.groupby(["crd_number", "year"])["b_crd_number"].apply(lambda s: frozenset(s.values))
setmap = g.to_dict()
def S(crd, yr): return setmap.get((int(crd), int(yr)), frozenset())


# ---- Actual mergers ----

# Load the merger sample
ms = pd.read_stata(PKG + "/2023/data/output/" + "merger_sample.dta")
ms["mergeryear"] = ms.mergeryear.astype(int)

# One row per deal: advisers at t-1, transfer share and headcounts
rows = []
for r in ms.itertuples():
    t, a, y = int(r.target_crd), int(r.acquirercrds), int(r.mergeryear)
    tm1 = S(t, y-1)
    rec = dict(deal_id=r.deal_id, tgt=t, acq=a, yr=y, deal_type=r.deal_type,
               n_tgt_m1=len(tm1), n_acq_m1=len(S(a, y-1)))
    # Transfer share: target advisers at t-1 who are at the acquirer at t+1
    rec["transfer_share"] = (len(tm1 & S(a, y+1)) / len(tm1)) if tm1 else np.nan
    # Target, acquirer and combined headcount by event year
    for k in range(-3, 4):
        rec[f"hc_{k}"] = len(S(t, y+k) | S(a, y+k))
        rec[f"tgt_{k}"] = len(S(t, y+k))
        rec[f"acq_{k}"] = len(S(a, y+k))
    rows.append(rec)

# Write the deal metrics that Appendix Figure A.2 plots
D = pd.DataFrame(rows)
D.to_csv(O + "/figA_deal_metrics.csv", index=False)


# ---- Pseudo pairs from the Table IX estimation frame ----

# Untreated (pseudo) pairs, one row per id
md = pd.read_stata(PKG + "/2023/data/output/" + "adviser_event_panel.dta")
ps = (md[md.treated == 0][["id", "acquired_year", "target_crd", "acquirer_crd"]]
      .drop_duplicates("id"))
ps["acquired_year"] = ps.acquired_year.astype(int)

# Transfer share and target and combined headcounts for each pseudo pair
prows = []
for r in ps.itertuples():
    t, a, y = int(r.target_crd), int(r.acquirer_crd), int(r.acquired_year)
    tm1 = S(t, y-1)
    rec = dict(id=r.id, tgt=t, acq=a, yr=y, n_tgt_m1=len(tm1))
    rec["transfer_share"] = (len(tm1 & S(a, y+1)) / len(tm1)) if tm1 else np.nan
    for k in range(-3, 4):
        rec[f"hc_{k}"] = len(S(t, y+k) | S(a, y+k))
        rec[f"tgt_{k}"] = len(S(t, y+k))
    prows.append(rec)

# Write the pseudo-pair diagnostic
P = pd.DataFrame(prows)
P.to_csv(O + "/figA_pseudo_metrics.csv", index=False)


# Print summary statistics for deals with target advisers at t-1: transfer share,
# median combined and target headcount indexed to t-1, and target exit shares
def rep(df, lab):
    d = df[df.n_tgt_m1 > 0].copy()
    print(f"\n=== {lab}: n={len(df)}, with target advisers at t-1: {len(d)}")
    print("  transfer share: median %.3f mean %.3f  >=0.5 %.3f  ==0 %.3f"
          % (d.transfer_share.median(), d.transfer_share.mean(),
             (d.transfer_share >= .5).mean(), (d.transfer_share == 0).mean()))
    base = d["hc_-1"].replace(0, np.nan)
    idx = {k: (d[f"hc_{k}"] / base).median() for k in range(-3, 4)}
    print("  combined headcount median index:", {k: round(v, 3) for k, v in idx.items()})
    tb = d["tgt_-1"].replace(0, np.nan)
    tidx = {k: (d[f"tgt_{k}"] / tb).median() for k in range(-3, 4)}
    print("  TARGET headcount median index:", {k: round(v, 3) for k, v in tidx.items()})
    ex = {k: (d[f"tgt_{k}"] == 0).mean() for k in range(0, 4)}
    print("  target exit (zero advisers) share:", {k: round(v, 3) for k, v in ex.items()})
    return d


# ---- Diagnostics printed to the log ----

# Summaries for actual mergers and pseudo pairs, and the repeat-acquirer count
da = rep(D, "actual mergers")
dp = rep(P, "PSEUDO pairs (Table IX frame)")
print("\nrepeat acquirers:", (ms.acquirercrds.value_counts() > 1).sum(),
      "of", ms.acquirercrds.nunique())
