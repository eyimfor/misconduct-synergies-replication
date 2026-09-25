# Table II: target and acquirer characteristics (2023/tables/stats_target_acquirer.tex).
# Also writes 2023/tables/merger_table.tex, a count of mergers, targets and acquirers by year.

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


# ---- Table II: target and acquirer characteristics ----

# Load the target and acquirer sample
data = pd.read_stata("2023/"
                         + 'data/output/target_acquirer_stats.dta')

# Variables to summarize and their row labels
columns_summary = ['crd', 'employees', 'fraction_bad_ever', 'fraction_bad_e_ever', 'fraction_bad_a', 'fraction_bad_e',
                   'fraction_bad_a_flow', 'fraction_bad_e_flow',
                   'dollar_aum','aum_growth_mean', 'number_clients', 'client_growth_mean']
labels_summary = ['crd', "# Employees", "Any Employee disclosures (All)", "Any Employee misconduct (EMS)",
                  "Employee disclosures (All)" , "Employee misconduct (EMS)" ,
                  "Disclosure growth (All)", "Misconduct growth (EMS)",
                  'AUM ($ Billions)', 'AUM growth', '# Clients (000s)',
                  "Client growth"]

# Group by target, cluster by crd; AUM in billions and clients in thousands
cluster_vars = ['crd']
byvar = ["target"]
data['target'] = data['target'].astype(float)
data['dollar_aum'] = data['dollar_aum']/1000
data['number_clients'] = data['number_clients']/1000

# Create summary statistics by group
by_group = ssm.table_by_group(df = data , byvar = byvar, Column_names = columns_summary, cluster_vars = cluster_vars ,
               labels = labels_summary)
by_group.columns = ['N', 'Mean', 'Std. Dev.', 'N', 'Mean',
       'Std. Dev.', 'N Difference', 'T-statistic']

# Export statistics by group to latex
by_group = by_group.iloc[:,[1, 2, 4, 5, 6,7]]
base_folder = '2023/'
by_group.to_latex(base_folder+'tables/stats_target_acquirer.tex', escape=False)


# ---- Mergers, targets and acquirers by year ----

# Count mergers and unique targets and acquirers by merger year
df = pd.read_stata('2023/data/output/merger_sample.dta')
df['mergeryear'] = df['mergeryear'].astype(int)
aggregated_data = df.groupby('mergeryear').agg(
    Num_Mergers=('mergeryear', 'size'),
    Unique_Targets=('target_crd', pd.Series.nunique),
    Unique_Acquirers=('acquirercrds', pd.Series.nunique)
).reset_index()

# Add a total row
total_row = {
    'mergeryear': 'Total',
    'Num_Mergers': aggregated_data['Num_Mergers'].sum(),
    'Unique_Targets': aggregated_data['Unique_Targets'].sum(),
    'Unique_Acquirers': aggregated_data['Unique_Acquirers'].sum(),
}
aggregated_data = pd.concat([aggregated_data, pd.DataFrame([total_row])], ignore_index=True)

# Export the table to a .tex file
tex_path = "2023/tables/merger_table.tex"
aggregated_data.to_latex(tex_path, index=False, header=['Year', '# Mergers', '# Unique Targets', '# Unique Acquirers'])
