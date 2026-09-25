"""Appendix Figure A.2 as three separate panel PNGs.

Panel A: share of target advisers retained; Panel B: combined headcount indexed to
t-1; Panel C: target deregistration. The PNGs carry no titles; the paper labels
the panels.
"""
import json
import warnings

import matplotlib
import numpy as np
import pandas as pd

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import seaborn as sns  # noqa: E402

warnings.filterwarnings("ignore")

# Input and output folders
import os
WORK = os.environ.get("WORK", "fig_work")  # scratch space
O = os.environ.get("OUT", WORK + "/appendix_figs")                 # where the panels are written
os.makedirs(O, exist_ok=True)

# Load deal metrics (deals with target advisers at t-1) and compute the plotted series
D = pd.read_csv(WORK + "/figA_deal_metrics.csv")
d = D[D.n_tgt_m1 > 0].copy()
ks = list(range(-3, 4))
base = d["hc_-1"].replace(0, np.nan)
idx = pd.DataFrame({k: d[f"hc_{k}"] / base for k in ks})
p25, p50, p75 = idx.quantile(.25), idx.median(), idx.quantile(.75)
exit_share = {k: (d[f"tgt_{k}"] == 0).mean() for k in range(0, 4)}

# Figure size and label fonts
SIZE = (11, 5)   # wide and short: three of these stack on one page
LAB = dict(fontsize=25, fontweight="bold")
# y-labels are rotated, so they must fit the 5in figure height: smaller and shorter
YLAB = dict(fontsize=19, fontweight="bold")


# Set tick size, remove the top and right spines, save the panel and close it
def finish(fig, ax, name):
    ax.tick_params(labelsize=21)
    sns.despine()
    fig.savefig(f"{O}/{name}", dpi=300, bbox_inches="tight")
    plt.close(fig)
    print("wrote", name)


# ---- (a) adviser transfer share ------------------------------------------

# Histogram of the retained share, with a dashed line at the median
sns.set(font_scale=2, style="white", rc=None)
fig, ax = plt.subplots(figsize=SIZE)
ax.hist(d.transfer_share.dropna(), bins=np.linspace(0, 1, 21),
        color="black", edgecolor="white", linewidth=0.8)
ax.axvline(d.transfer_share.median(), color="0.35", linestyle="--", linewidth=2)
ax.set_xlabel("Share of target advisers retained", **LAB)
ax.set_ylabel("Number of mergers", **YLAB)
finish(fig, ax, "figA2_panelA_transfer.png")


# ---- (b) combined headcount, indexed to t-1 -------------------------------

# No fill and no legend: three quantile traces labelled where they end
fig, ax = plt.subplots(figsize=SIZE)
ax.plot(ks, p25.values, color="0.55", linewidth=1.4)
ax.plot(ks, p75.values, color="0.55", linewidth=1.4)
ax.plot(ks, p50.values, color="black", linewidth=2.6)
ax.axhline(1.0, color="0.80", linewidth=0.8, zorder=0)
for series, txt in ((p75, "75th"), (p50, "Median"), (p25, "25th")):
    ax.annotate(txt, xy=(ks[-1], series.values[-1]), xytext=(6, 0),
                textcoords="offset points", va="center", ha="left",
                fontsize=19, color="black" if txt == "Median" else "0.40")

# Axes and labels
ax.set_xlim(ks[0] - 0.15, ks[-1] + 1.15)
ax.set_xticks(ks)
ax.set_xlabel("Years relative to the merger", **LAB)
ax.set_ylabel("Headcount ($t-1=1$)", **YLAB)
finish(fig, ax, "figA2_panelB_headcount.png")


# ---- (c) target deregistration -------------------------------------------

# Bars of the share of targets deregistered in each year, labelled with the percentage
fig, ax = plt.subplots(figsize=SIZE)
kk = list(range(0, 4))
ax.bar(kk, [100 * exit_share[k] for k in kk], color="black", width=0.6)
for k in kk:
    ax.text(k, 100 * exit_share[k] + 1.5, f"{100*exit_share[k]:.0f}%",
            ha="center", va="bottom", fontsize=21, fontweight="bold")

# Axes and labels
ax.set_ylim(0, 105)
ax.set_xticks(kk)
ax.set_xlabel("Years relative to the merger", **LAB)
ax.set_ylabel("Targets deregistered (%)", **YLAB)
finish(fig, ax, "figA2_panelC_deregistration.png")

# Write summary statistics for the three panels
json.dump(dict(
    n_deals=int(len(D)), n_deals_used=int(len(d)),
    transfer_median=float(d.transfer_share.median()),
    target_exit={str(k): float(exit_share[k]) for k in kk},
), open(WORK + "/figA_panels_stats.json", "w"), indent=1)
