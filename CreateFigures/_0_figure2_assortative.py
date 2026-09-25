# Figure 2: probability of a merger by whether the acquirer and the target have
# employee disclosures. Writes figures/assortative_matching.png.
import os

# Work from the package's 2023/ folder; paths below are relative to it
PKG = os.environ.get("PKG", ".")   # package root
os.chdir(os.path.join(PKG, '2023'))   # paths below are relative to 2023/

# Import required packages
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')

# Load the matching frame
assortative_matching = pd.read_stata(""
                         + 'data/output/matching_frame.dta')

# Bar positions on a 2 x 2 grid, and bar heights: the mean of real_match for each
# combination of misc_cut_aa and misc_cut_ta
_x = np.arange(2)
_y = np.arange(2)
_xx, _yy = np.meshgrid(_x, _y, indexing="ij")   # ij indexing matches the groupby key order
x, y = _xx.ravel(), _yy.ravel()
top = np.array(assortative_matching.groupby(['misc_cut_aa', 'misc_cut_ta'])['real_match'].mean().tolist()).round(2)

# Bar base, width and depth
bottom = np.zeros_like(top)
width = depth = 1

# Draw the 3D bar chart
from mpl_toolkits import mplot3d
sns.set(font_scale = 1, style = 'white', rc=None)
fig = plt.figure(figsize=(12,10))
ax = plt.axes(projection='3d')
ax.bar3d(x, y,
          bottom, width, depth, top, color= '#000000', alpha=0.5)

# Axis titles and tick labels
ax.set_xlabel("Acquirer Disclosures", fontsize='large')
ax.set_ylabel("Target Disclosures" , fontsize='large')
ticksx = np.arange(3)
column_names_x = ['No Disclosure', "" , 'Some Disclosure']
column_names_y = ['',
                  "" , '                               Some Disclosure']
plt.xticks(ticksx, column_names_x)
plt.yticks(ticksx, column_names_y)
ax.set_zlabel("Probability of Merger (%)" , fontsize='large')

# Value labels on top of bars (white, bold), then save
for i in range(len(x)):
    ax.text(x[i]+0.5, y[i]+0.5, top[i]+0.2, f'{top[i]:.2f}%', ha='center', va='bottom', fontsize=16, fontweight='bold', color='white')
plt.savefig("figures/assortative_matching.png", dpi = 300);
