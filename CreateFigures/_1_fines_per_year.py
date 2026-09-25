# Figure A.1: aggregate misconduct settlements by year (misconduct_trends_employee.png).
# Paths are relative to the package root.

# Set the working directory to the package root and load packages
import os
PKG = os.environ.get("PKG", ".")   # package root
os.chdir(PKG)   # paths below are relative to the package root
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')
import statsmodels.api as sm

# Load settlements by year
settlements_by_year = pd.read_stata('2023/data/output/rr_disclosures_yearly.dta')

# Plot settlements by year
fig, ax = plt.subplots(figsize=(12,10))
sns.set(font_scale = 2, style = 'white', rc=None)
ax = sns.lineplot(x="year", y="settlement", err_style = None, estimator = 'mean',
                  data=settlements_by_year,  marker = 'X', color = 'dimgray', linewidth = 3)

# Axis labels and ticks
ax.set_xlabel("", fontsize=25, fontweight = 'bold')
plot_years = sorted(settlements_by_year["year"].astype(int).unique())
ax.set_xticks(plot_years)
xlabels = [str(x) for x in plot_years]
ax.set_xticklabels(xlabels, rotation=40)
ax.set_ylabel("Misconduct Fines ($ Millions)" , fontsize=25, fontweight = 'bold')

# Remove the top and right spines and save the figure
sns.despine();
plt.savefig("2023/figures/misconduct_trends_employee.png", bbox_inches = 'tight', dpi = 300);
