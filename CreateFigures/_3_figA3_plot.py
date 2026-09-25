"""Appendix Figure A.3: robustness of the post-merger decline in disclosures.
Writes figA3_panelA_dynamic.png and figA3_panelB_alternatives.png.

Panel (a): baseline-relative dynamic DiD, full estimation frame vs the "clean event"
frame that drops every cohort in which any of the four firms (real target, real
acquirer, pseudo target, pseudo acquirer) appears in another observed merger within
+/-3 years of the focal deal (the repeat-acquirer check).

Panel (b): the average post-merger interaction across alternative denominators,
disclosure categories and event dates.

All estimates are read from panelA_estimates.json and panelB_estimates.json in $WORK,
written by figA3_estimation/run_figA3.py.
"""
import json, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns
import warnings; warnings.filterwarnings("ignore")
import os

# Paths, overridable from the environment
R = os.environ.get("WORK", "fig_work")     # scratch space
O = os.environ.get("OUT", R)                                       # where the figure is written

# Load the estimates, keyed by specification/outcome/term (Panel A) and model/term (Panel B)
pa = json.load(open(R + "/panelA_estimates.json"))
pb = json.load(open(R + "/panelB_estimates.json"))
E = {(r["specification"], r["outcome"], r["term"]): r for r in pa["estimates"]}
G = {(r["model"], r["term"]): r for r in pb["estimates"]}

# Event years; year -1 is the omitted base year
XS = [-3, -2, -1, 0, 1, 2, 3]


def path(spec, out):
    # Coefficients and 95% bounds by event year, with zeros at the base year
    b, lo, hi = [], [], []
    for k, t in zip(XS, ["te_m3", "te_m2", None, "te_0", "te_p1", "te_p2", "te_p3"]):
        if t is None:
            b.append(0.0); lo.append(0.0); hi.append(0.0); continue
        r = E[(spec, out, t)]
        b.append(r["coefficient"]); lo.append(r["lower95"]); hi.append(r["upper95"])
    return np.array(b), np.array(lo), np.array(hi)


# Set up one figure per panel
sns.set(font_scale=2, style="white", rc=None)
figA_, axA_ = plt.subplots(figsize=(12, 9))
figB_, axB_ = plt.subplots(figsize=(13, 9))
axes = [axA_, axB_]


# ---- Panel (a): dynamic paths ----

# Plot the full-frame and single-merger-cohort paths, offset horizontally
ax = axes[0]
ncoh = lambda spec: int(E[(spec, "All", "te_0")]["N_clusters"])   # cohorts = clusters
specs = [("dynamic_full", r"All cohorts (%d)" % ncoh("dynamic_full"), "black", "o", "-", -0.09),
         ("dynamic_clean", r"Single-merger cohorts (%d)" % ncoh("dynamic_clean"),
          "dimgrey", "s", "--", 0.09)]
for spec, lab, col, mk, ls, off in specs:
    b, lo, hi = path(spec, "All")
    x = np.array(XS, dtype=float) + off
    ax.errorbar(x, b, yerr=[b - lo, hi - b], fmt=mk, color=col, ecolor=col,
                markersize=12, linewidth=2.5, elinewidth=2.5, capsize=6,
                linestyle=ls, label=lab, markerfacecolor=("white" if mk == "s" else col))

# Reference lines, axis labels and legend
ax.axhline(0, color="black", linewidth=1.2)
ax.axvline(-0.5, color="dimgrey", linestyle=":", linewidth=2)
ax.set_xticks(XS); ax.tick_params(labelsize=21)
ax.set_xlabel("Years relative to the merger", fontsize=25, fontweight="bold")
ax.set_ylabel(r"Merged $\times$ event year", fontsize=25, fontweight="bold")
ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.16), ncol=1,
          frameon=False, fontsize=21)


# ---- Panel (b): robustness of the average effect ----

# One row per specification: label, All estimate, EMS estimate
rows = [
    ("Baseline specification",
     E[("static_record_rate", "All", "interaction")],
     E[("static_record_rate", "EMS", "interaction")]),
    ("Distinct advisers in the denominator",
     E[("static_unique_adviser_rate", "All", "interaction")],
     E[("static_unique_adviser_rate", "EMS", "interaction")]),
    ("Excluding separations after allegations",
     G[("all_nosep_three", "tp")], G[("ems_nosep_three", "tp")]),
    ("Announcement year",
     G[("all_announce", "tp_announce")], G[("ems_announce", "tp_announce")]),
    ("Closing year",
     G[("all_closing", "tp_closing")], G[("ems_closing", "tp_closing")]),
    # The repeat-acquirer subsample is shown as a dynamic path in Panel A and is
    # not repeated here.
]


def unpack(r):
    # Coefficient and 95% bounds, whichever estimates file the row came from
    if "coefficient" in r:
        return r["coefficient"], r["lower95"], r["upper95"]
    return r["b"], r["lo95"], r["hi95"]


# Plot the All and EMS estimates for each row, offset vertically
ax = axes[1]
y = np.arange(len(rows))[::-1].astype(float)
for j, (out, col, mk, off, lab) in enumerate(
        [(1, "black", "o", 0.14, "Employee Disclosures (All)"),
         (2, "dimgrey", "s", -0.14, "Employee Misconduct (EMS)")]):
    bs, los, his = zip(*[unpack(r[out]) for r in rows])
    bs, los, his = np.array(bs), np.array(los), np.array(his)
    ax.errorbar(bs, y + off, xerr=[bs - los, his - bs], fmt=mk, color=col,
                ecolor=col, markersize=13, elinewidth=2.5, capsize=6, linestyle="none",
                label=lab, markerfacecolor=("white" if mk == "s" else col))

# Reference line, row labels, axis label and legend
ax.axvline(0, color="black", linewidth=1.2)
ax.set_yticks(y)
ax.set_yticklabels([r[0] for r in rows], fontsize=20)
ax.set_ylim(-0.7, len(rows) - 0.3)
ax.tick_params(labelsize=21)
ax.set_xlabel(r"Merged $\times$ Post", fontsize=25, fontweight="bold")
ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.16), ncol=2,
          frameon=False, fontsize=21)


# ---- Output ----

# Save both panels
for _f in (figA_, figB_):
    sns.despine(fig=_f)
    _f.tight_layout()
for _f,_n in ((figA_,"figA3_panelA_dynamic.png"),(figB_,"figA3_panelB_alternatives.png")):
    _f.savefig(O + "/" + _n, bbox_inches="tight", dpi=300)
    print("wrote", _n)

# Print the Panel (b) estimates
for r in rows:
    print(r[0], "| All", [round(v, 4) for v in unpack(r[1])],
          "| EMS", [round(v, 4) for v in unpack(r[2])])
