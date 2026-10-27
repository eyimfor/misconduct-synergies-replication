# Figure 2, Panel B: probability of a merger by target and acquirer disclosure status,
# matching within state (assortative_matching_emploc_robust.png).
# Paths are relative to the package root
import os
PKG = os.environ.get("PKG", ".")   # package root
os.chdir(PKG)   # paths below are relative to the package root
import sys

# Import required packages
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')

# Load the within-state matching frame
assortative_matching = pd.read_stata("2023/"
                         + 'data/output/matching_frame_tw.dta')

# Define axes and bar heights (mean merger probability per cell)
_x = np.arange(2)
_y = np.arange(2)
_xx, _yy = np.meshgrid(_x, _y, indexing="ij")   # ij indexing matches the groupby key order
x, y = _xx.ravel(), _yy.ravel()
top = np.array(assortative_matching.groupby(['misc_cut_aa', 'misc_cut_ta'])['real_match'].mean().tolist()).round(2)

# Define bar base, width and depth
bottom = np.zeros_like(top)
width = depth = 1

# Draw the 3D bar chart
from mpl_toolkits import mplot3d
sns.set(font_scale = 1, style = 'white', rc=None)
fig = plt.figure(figsize=(12,10))
ax = plt.axes(projection='3d')
ax.bar3d(x, y,
         bottom, width, depth, top, color= '#000000', alpha=0.5)

# Add value labels on top of bars in white
for i in range(len(x)):
   ax.text(x[i]+0.5, y[i]+0.5, top[i]+0.2, f'{top[i]:.2f}%',
           ha='center', va='bottom', fontsize=16, fontweight='bold', color='white')

# Axis labels with increased labelpad for distance
ax.set_xlabel("Acquirer Disclosures", fontsize='large', labelpad=15)
ax.set_ylabel("Target Disclosures", fontsize='large', labelpad=15)
ax.set_zlabel("Probability of Merger (%)", fontsize='large')

# Fix tick positions and labels
ax.set_xticks([0.5, 1.5])
ax.set_xticklabels(['No Disclosure', 'Some Disclosure'])
ax.set_yticks([0.5, 1.5])
ax.set_yticklabels(['No Disclosure', 'Some Disclosure'])

# Save the figure
plt.savefig("2023/figures/assortative_matching_emploc_robust.png", dpi=300);
