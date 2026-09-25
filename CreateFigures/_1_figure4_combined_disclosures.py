# Produces Figure 4 (combined-firm disclosures DiD): plottable11.png.
# Regresses employee disclosures on event-time dummies and their interactions with the
# merged indicator (t=-1 omitted) and plots the interaction coefficients with 95% CIs.

# Set up paths (relative to the package root) and imports
import os
PKG = os.environ.get("PKG", ".")   # package root
OUT = os.environ.get("OUT", PKG + "/2023/figures")     # figure output folder
os.chdir(PKG)   # paths below are relative to the package root
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')
import statsmodels.api as sm

# Load the Figure 4 sample and build event-time dummies (t=-1 omitted)
df = pd.read_stata('2023/data/output/misconductdroptest_figure4.dta')
event_time_dummies = pd.get_dummies(df['event_time'].astype(int), prefix='event_time')
event_time_dummies = event_time_dummies.drop(columns=['event_time_-1'])

# Create interaction terms
for col in event_time_dummies.columns:
    event_time_dummies[f"{col}_treated"] = event_time_dummies[col] * df['treated']

# Regressors and outcome
X = event_time_dummies
X = sm.add_constant(X).astype(float)
y = df['fraction_bad_a_flow'].astype(float)

# Conventional OLS standard errors (not clustered)
model = sm.OLS(y, X)
results = model.fit()
coefficients = results.params
conf_int = results.conf_int(alpha=0.05)
coefficients = coefficients[7:]   # keep the six event-time x merged interactions
conf_int = conf_int[7:]

# Plot style and figure size
sns.set(font_scale=2, style='white', rc=None)
plt.figure(figsize=(12, 10))
cap_size = 0.1  # half-width of the CI caps, in x units

# Plot bold solid line at zero
plt.axhline(0, color='black', linewidth=4)

# Plot confidence intervals with caps
for idx, (coef, conf) in enumerate(zip(coefficients, conf_int.values)):
    if idx < 2:  # t=-3 and t=-2
        plt_idx = idx
        plt.plot([plt_idx, plt_idx], conf, color='black', linewidth=1.5)
        plt.plot([plt_idx - cap_size, plt_idx + cap_size], [conf[0], conf[0]], color='black', linewidth=1.5)
        plt.plot([plt_idx - cap_size, plt_idx + cap_size], [conf[1], conf[1]], color='black', linewidth=1.5)

    elif idx >= 2:  # t=0 to t=3, shifted one slot to leave room for t=-1
        plt_idx = idx +1
        plt.plot([plt_idx, plt_idx], conf, color='black', linewidth=1.5)
        plt.plot([plt_idx - cap_size, plt_idx + cap_size], [conf[0], conf[0]], color='black', linewidth=1.5)
        plt.plot([plt_idx - cap_size, plt_idx + cap_size], [conf[1], conf[1]], color='black', linewidth=1.5)

# Plot coefficients
plt.scatter(range(0, 2), coefficients[:2], color='black', s = 100)
plt.scatter(range(3, 7), coefficients[2:6], color='black', s = 100)

# Plot a dot for event_time_-1
plt.scatter(2, 0, color='black', s = 100)

# Configure plot
plt.xticks(range(7), ['-3', '-2', '-1', '0', '1', '2', '3'])
plt.xlabel('Years Relative to Merger',fontsize=30, fontweight='bold')
plt.ylabel('Merged X t', fontsize=30, fontweight='bold')
plt.legend()
sns.despine()

# Save to the package's figure folder
plt.savefig(OUT + "/plottable11.png", bbox_inches = 'tight', dpi = 300);
