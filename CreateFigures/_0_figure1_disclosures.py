"""Figure 1: disclosures by firm type (DisclosuresAll.png).

Mean share of employees with any disclosure at targets, acquirers and other firms,
2009-2020 in three periods, with bootstrapped 95% confidence intervals. The legend
sits above the axes so it does not cover the bars.
"""
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings("ignore")

import os
PKG = os.environ.get("PKG", ".")          # package root
OUT = os.environ.get("OUT", PKG + "/2023/figures")           # same folder as every other figure

# Load the firm-year panel, keep 2009-2020 and label the firm types
df = pd.read_stata(PKG + "/2023/data/output/finestargetacquirer.dta")
df["year"] = df["year"].astype(int)
df = df[(df["year"] >= 2009) & (df["year"] <= 2020)]
df["target"] = df["target"].replace({0: "Acquirer", 1: "Target", 2: "Other"})
df["target"] = pd.Categorical(df["target"], categories=["Other", "Acquirer", "Target"], ordered=True)


# Map each year to its four-year period
def map_years(year):
    if 2009 <= year <= 2012:
        return "2009-2012"
    if 2013 <= year <= 2016:
        return "2013-2016"
    if 2017 <= year <= 2020:
        return "2017-2020"


# Assign the periods and sort by period
df["year_group"] = df["year"].apply(map_years)
order = ["2009-2012", "2013-2016", "2017-2020"]
df["year_group"] = pd.Categorical(df["year_group"], categories=order, ordered=True)
df = df.sort_values("year_group", kind="mergesort")   # stable: the seeded bootstrap indexes positionally

# Draw the bar chart with seeded bootstrap confidence intervals
# seaborn's default 95% CI is a 1000-draw bootstrap from an unseeded RNG. Without seed=
# the whiskers move every run, and through matplotlib's y autoscale so do the bar tops and
# tick labels. seed= has to be passed here: np.random.seed() has no effect, because seaborn
# calls np.random.default_rng(seed) with its own seed=None.
fig, ax = plt.subplots(figsize=(12, 10))
sns.set(font_scale=2, style="white", rc=None)
sns.barplot(data=df, x="year_group", y="all_misconduct_all", hue="target",
            palette=["black", "lightgrey", "darkgrey"], capsize=0.1, seed=0, n_boot=10000)
# Axis labels smaller and tick labels larger, so the two read at the same scale
plt.xlabel("Year", fontsize=20, fontweight="bold")
plt.ylabel("Employees with any disclosure (%)", fontsize=20, fontweight="bold")
ax.tick_params(axis="both", labelsize=20)

# Place the legend above the axes in one row with no frame, so it cannot collide with the bars
plt.legend(title="", loc="lower center", bbox_to_anchor=(0.5, 1.005),
           ncol=3, frameon=False, fontsize=20)
sns.despine()

# Save the figure
plt.savefig(OUT + "/DisclosuresAll.png", bbox_inches="tight", dpi=300)
print("wrote", OUT + "/DisclosuresAll.png")

# Print the plotted means as a check on the figure
chk = df.groupby(["year_group", "target"], observed=True)["all_misconduct_all"].mean().round(3)
print(chk.to_string())
