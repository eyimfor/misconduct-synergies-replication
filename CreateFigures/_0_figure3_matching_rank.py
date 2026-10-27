# Figure 3: matching on misconduct in ranks. The target's within-year misconduct percentile against
# the acquirer's, actual mergers versus counterfactual pairs, one panel per candidate-pair sample:
# all pairs (Panel A, from matching_frame.dta) and within state (Panel B, from matching_frame_tw.dta).
# Writes 2023/figures/matching_rank_panelA_all.png and matching_rank_panelB_state.png, and
# 2023/figures/matching_rank_numbers.json: the slopes, Spearman correlations and permutation
# bands the text quotes.
import json, os

# Work from the package root; paths below are relative to it
PKG = os.environ.get("PKG", ".")   # package root
os.chdir(PKG)

# Import required packages
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats

# The two candidate-pair frames, before the regression sample rule, and the seed of the permutation test
FRAMES = [("matching_frame", "all", "A"), ("matching_frame_tw", "state", "B")]
rng = np.random.default_rng(0)

# Percentile rank of a firm's misconduct rate among the distinct firms on its side of the market in
# the year, scaled 0 to 1, ties averaged
def firm_pct(df, crd, col):
    f = df[["acquired_year", crd, col]].drop_duplicates(["acquired_year", crd]).copy()
    f["r"] = f.groupby("acquired_year")[col].rank(method="average")
    f["n"] = f.groupby("acquired_year")[col].transform("size")
    f["pct"] = (f["r"] - 1) / (f["n"] - 1)
    return df.merge(f[["acquired_year", crd, "pct"]], on=["acquired_year", crd], how="left")["pct"].values

# One panel per frame
results = {}
sns.set(font_scale=2, style="white", rc=None)
for frame, tag, panel in FRAMES:

    # Load the frame, keep the sample years, and rank each side within the year (All measure)
    df = pd.read_stata(f"2023/data/output/{frame}.dta")
    df = df[(df["acquired_year"] >= 2011) & (df["acquired_year"] <= 2020)].copy()
    df["pA"] = firm_pct(df, "acquirer_crd", "acquirer_misc_a")
    df["pT"] = firm_pct(df, "target_crd", "target_misc_a")
    df["m"] = (df["real_match"] == 100).astype(int)
    act, cf = df[df["m"] == 1], df[df["m"] == 0]

    # Slopes of the target's rank on the acquirer's, actual against counterfactual pairs, and a
    # permutation null for the Spearman correlation: re-pair each year's targets and acquirers at random
    sa = stats.linregress(act["pA"], act["pT"])
    sc = stats.linregress(cf["pA"], cf["pT"])
    rho_a = stats.spearmanr(act["pA"], act["pT"]).correlation
    null = []
    for _ in range(2000):
        rs = [pd.DataFrame({"pA": g["pA"].values, "pT": rng.permutation(g["pT"].values)}) for _, g in act.groupby("acquired_year")]
        p = pd.concat(rs)
        null.append(stats.spearmanr(p["pA"], p["pT"]).correlation)
    null = np.array(null)
    results[tag] = dict(n_pairs=int(len(df)), n_act=int(len(act)), n_cf=int(len(cf)), base=float(100 * df["m"].mean()),
                        slope_act=float(sa.slope), se_act=float(sa.stderr), slope_cf=float(sc.slope), se_cf=float(sc.stderr),
                        rho_act=float(rho_a), null_lo=float(np.percentile(null, 2.5)), null_hi=float(np.percentile(null, 97.5)),
                        p_perm=float((null >= rho_a).mean()))

    # Binned scatter by decile of the acquirer's rank, with the OLS fits over every pair. Deciles with
    # fewer than 15 pairs are not drawn (one holds a single merger, another twelve near-identical ones)
    fig, ax = plt.subplots(figsize=(12, 9))
    bins = np.linspace(0, 1, 11)
    for sub, lab, col, mk, res, lw, ls in [(cf, "Counterfactual pairs", "0.55", "s", sc, 2, "--"),
                                           (act, "Actual mergers", "black", "o", sa, 3, "-")]:
        b = pd.cut(sub["pA"], bins, include_lowest=True)
        g = sub.groupby(b, observed=True)["pT"].agg(["mean", "sem", "count"])
        g = g[g["count"] >= 15]
        x = np.array([iv.mid for iv in g.index])
        ax.errorbar(x, g["mean"], yerr=(1.96 * g["sem"] if lab == "Actual mergers" else None), fmt=mk, color=col,
                    ms=11, capsize=4, lw=1.5, label=lab)
        xx = np.linspace(0, 1, 50)
        ax.plot(xx, res.intercept + res.slope * xx, color=col, lw=lw, ls=ls)

    # Axis labels, legend above the axes, and the saved panel
    ax.set_xlabel("Acquirer misconduct, within-year percentile rank", fontsize=20, fontweight="bold")
    ax.set_ylabel("Target misconduct, within-year percentile rank", fontsize=20, fontweight="bold")
    ax.tick_params(axis="both", labelsize=20)
    ax.set_xlim(0, 1)
    ax.set_ylim(0.25, 0.75)
    ax.legend(loc="lower center", bbox_to_anchor=(0.5, 1.005), ncol=2, frameon=False, fontsize=20)
    sns.despine()
    fig.savefig(f"2023/figures/matching_rank_panel{panel}_{tag}.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

# The numbers the text quotes
json.dump(results, open("2023/figures/matching_rank_numbers.json", "w"), indent=1)
for k, r in results.items():
    print(k)
    for a, v in r.items():
        print(f"  {a}: {v}")
