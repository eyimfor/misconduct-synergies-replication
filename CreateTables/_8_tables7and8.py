# Tables VII and VIII: summary statistics for the combined firm before and after
# real mergers (Table VII) and pseudo mergers (Table VIII).

# Set up paths (relative to the package root) and imports
import os
PKG = os.environ.get("PKG", ".")   # package root
os.chdir(PKG)   # paths below are relative to the package root
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # summary_stats_group.py
import pandas as pd
import summary_stats_group as ssm
import warnings
warnings.filterwarnings('ignore')


# ---- Table VII: real merging firms ----

# Load the Table VII sample and keep real merging firms (treated == 1)
data = pd.read_stata("2023/"
                         + 'data/output/misconductdroptest_table7.dta')
data = data[data['treated'] == 1]

# Variables to summarize and their row labels
columns_summary = ['id', 'employees','fraction_bad_a_flow', 'fraction_bad_e_flow',
                   'all_intensity_flow1', 'egan_intensity_flow1', 'dollar_aumc',
                   'combined_aumg', 'number_clientsc', 'combined_clg']
labels_summary = ['crd', "# Employees", "Employees misconduct (All)" , "Employees misconduct (EMS)" ,
                  "Misconduct growth (All)", "Misconduct growth (EMS)",
                  'AUM ($ Billions)', 'AUM growth', '# Clients (000s)',
                  "Client growth"]

# Group by post, cluster by id; AUM in billions and clients in thousands
cluster_vars = ['id']
byvar = ["post"]
data['post'] = data['post'].astype(float)
data['dollar_aumc'] = data['dollar_aumc']/1000
data['number_clientsc'] = data['number_clientsc']/1000

# Create summary statistics by group
by_group = ssm.table_by_group(df = data , byvar = byvar, Column_names = columns_summary, cluster_vars = cluster_vars ,
               labels = labels_summary)
by_group.columns = ['N', 'Mean', 'Std. Dev.', 'N', 'Mean',
       'Std. Dev.', 'N Difference', 'T-statistic']

# Export statistics by group to latex
by_group = by_group[1:]
by_group = by_group.iloc[:,[1,2,4,5,6,7]]
base_folder = '2023/'
by_group.to_latex(base_folder+'tables/stats_target_acquirerpp.tex', escape = False)


# ---- Table VIII: pseudo merging firms ----

# Load the Table VIII sample and keep pseudo merging firms (treated == 0)
data = pd.read_stata("2023/"
                         + 'data/output/misconductdroptest_table8.dta')
data = data[data['treated'] == 0]

# Variables to summarize and their row labels
columns_summary = ['id', 'employees','fraction_bad_a_flow', 'fraction_bad_e_flow',
                   'all_intensity_flow1', 'egan_intensity_flow1', 'dollar_aumc',
                   'combined_aumg', 'number_clientsc', 'combined_clg']
labels_summary = ['crd', "# Employees", "Employees misconduct (All)" , "Employees misconduct (EMS)" ,
                  "Misconduct growth (All)", "Misconduct growth (EMS)",
                  'AUM ($ Billions)', 'AUM growth', '# Clients (000s)',
                  "Client growth"]

# Group by post, cluster by id; AUM in billions and clients in thousands
cluster_vars = ['id']
byvar = ["post"]
data['post'] = data['post'].astype(float)
data['dollar_aumc'] = data['dollar_aumc']/1000
data['number_clientsc'] = data['number_clientsc']/1000

# Create summary statistics by group
by_group = ssm.table_by_group(df = data , byvar = byvar, Column_names = columns_summary, cluster_vars = cluster_vars ,
               labels = labels_summary)
by_group.columns = ['N', 'Mean', 'Std. Dev.', 'N', 'Mean',
       'Std. Dev.', 'N Difference', 'T-statistic']

# Export statistics by group to latex
by_group = by_group[1:]
by_group = by_group.iloc[:,[1,2,4,5,6,7]]
base_folder = '2023/'
by_group.to_latex(base_folder+'tables/stats_target_acquirerppf.tex', escape = False)
