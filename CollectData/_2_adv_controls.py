# ******************************************************************************
# Raw SEC Form ADV bulk files -> all_controls_2023.csv
#
# One row per Form ADV filing. This is the firm-level control file:
# BuildPanels/build_fiscal_year_filings.do and build_firm_controls_data.do read it to
# build firm_adv_controls.dta.
#
#   - Files are read in sorted order, so row order is the same on every platform.
#   - Retail_clients is determined row by row. Pre-2017 filings report item 5D1 as
#     a percentage bucket ('26-50%'); later filings report a client count.
#   - A file that cannot be read, or lacks the expected columns, is skipped and
#     listed at the end of the run.
#
# usage: _2_adv_controls.py (no arguments; RAW, WORK and PKG are read from the environment)
# ******************************************************************************

import os
import pandas as pd

# Paths, overridable from the environment
RAW  = os.environ.get("RAW",  "../collect_work/raw_unpacked")           # the raw/ folder, unpacked
WORK = os.environ.get("WORK", "../collect_work")       # scratch space
adv_folder = RAW  + "/form_adv_complete/ria2023_subset"

# Write where the pipeline reads. run_collect.sh exports PKG; with PKG unset the
# output goes to the scratch folder.
PKG  = os.environ.get("PKG", "")
out_folder = (PKG + "/2023/data/input") if PKG else WORK + "/output"

# Form ADV base files are the ones whose names contain this pattern
file_pattern = "_Base_A_"

# The columns the pre-2012 form uses; the newer form is renamed onto these below
keep_columns_pre_2012 = ['FormVersion', 'Execution Date', 'FilingID', '1A', '1B1', '1E',
    '1F1-Street 1', '1F1-Street 2', '1F1-City', '1F1-State', '1F1-Country', '1F1-Postal',
    '5A-Number', '5B1', '5B2-Number', '5B3', '5B4', '5B6', '5D1/5D1a', '5E1', '5E2',
    '5E4', '5E5', '5E6', '5G1', '5G2', '5G3', '5G4', '5G5', '5G6', '5G7', '5G8', '5G9',
    '5G10', '5G11', '5G12', '5F2c', '5F2f', '6A1', '8A1', '8A2', '8A3', '8B1', '8B2',
    '8B3', '8E', '8F', '8G1', '9A1/9A1a', '9A2/9A1b', '9B1/9B1a', '9B2/9B1b',
    '11A1', '11A2', '11B1', '11B2', '11C1', '11C2', '11C3', '11C4', '11C5',
    '11D1', '11D2', '11D3', '11D4', '11D5', '11E1', '11E2', '11E3', '11E4', '11F',
    '11G', '11H1a', '11H1b', '11H1c', '11H2']

# The columns written to all_controls_2023.csv, in output order
keep_columns_final = ['FormVersion', 'Execution_Date', 'FilingID', 'Legal_name', 'Business_Name',
    'CRD', 'Street_One', 'City', 'State', 'Country', 'Zipcode', 'Past_Criminal_felony',
    'Past_Criminal_misdemeanor', 'Past Regulatory', 'Past Civil', 'Referral fees',
    'Interest in transacton', 'Conflicted advice', 'Soft Dollars', 'Soliciting_clients',
    'Retail_clients', 'Custody', 'compensation_aum', 'compensation_hourly',
    'compensation_fixed', 'compensation_commission', 'compensation_performance',
    'dollar_AUM', 'broker_dealer_dummy', 'emp_advisory_functions', 'Brokers_in_firm',
    'Total_employees', 'Number_clients', 'Financial_planning', 'Port_mgmt_indv_sb',
    'Port_mgmt_inv_c', 'Port_mgmt_pif', 'total_employees_advisers', 'total_employees_others',
    'Port_mgmt_bus_insc', 'Pension_cs', 'Selection_advisers', 'Publication_periodicals',
    'Ratings_pricing', 'Market_Timing', 'Education_Seminars', 'Other']

# Sorted, so row order is the same on every run
file_names = sorted(f for f in os.listdir(adv_folder) if file_pattern in f)
print("files to read:", len(file_names))

# Write the header once, then append one file at a time
out_path = os.path.join(out_folder, "all_controls_2023.csv")
os.makedirs(out_folder, exist_ok=True)
pd.DataFrame(columns=keep_columns_final).to_csv(out_path, index=False, encoding="utf-8")

# Process one Form ADV file at a time
n_rows = 0
failed = []
for file in file_names:
    # Read the file as strings; a file that cannot be read is skipped
    try:
        data = pd.read_csv(os.path.join(adv_folder, file), encoding="ISO-8859-1",
                           low_memory=False, dtype=str)
    except Exception as e:
        failed.append((file, "read: " + str(e)[:60]))
        continue

    # Harmonise the column names that changed across form versions
    if '1E1' in data.columns:
        data.rename(columns={'1E1': '1E'}, inplace=True)
    if '5A-Range' in data.columns:
        data.loc[data['5A-Number'].isna(), '5A-Number'] = data['5A-Range']
    if '5B1-Range' in data.columns:
        data.loc[data['5B1-Number'].isna(), '5B1-Number'] = data['5B1-Range']
    if '5B2-Range' in data.columns:
        data.loc[data['5B2-Number'].isna(), '5B2-Number'] = data['5B2-Range']
    if '5B3-Range' in data.columns:
        data.loc[data['5B3-Number'].isna(), '5B3-Number'] = data['5B3-Range']
    if '5B3-Number' in data.columns:
        data.rename(columns={'5B3-Number': '5B3'}, inplace=True)

    # The newer form uses different names; map them onto the pre-2012 ones
    try:
        data = data[keep_columns_pre_2012]
    except KeyError:
        data.rename(columns={'5A': '5A-Number', '5B2': '5B2-Number', '5D1a': '5D1/5D1a',
                             '9A1a': '9A1/9A1a', '9A1b': '9A2/9A1b', '5B1-Number': '5B1',
                             '9B1a': '9B1/9B1a', '9B1b': '9B2/9B1b', '1B': '1B1'}, inplace=True)
        try:
            data = data[keep_columns_pre_2012]
        except KeyError as e:
            failed.append((file, "columns: " + str(e)[:60]))
            continue

    # Disciplinary history
    data['Past_Criminal_felony'] = (data.loc[:, '11A1':'11A2'] == 'Y').astype(int).sum(axis=1)
    data['Past_Criminal_misdemeanor'] = (data.loc[:, '11B1':'11B2'] == 'Y').astype(int).sum(axis=1)
    data['Past Regulatory'] = (data.loc[:, '11C1':'11G'] == 'Y').astype(int).sum(axis=1)
    data['Past Civil'] = (data.loc[:, '11H1a':'11H2'] == 'Y').astype(int).sum(axis=1)

    # Conflicts of interest
    data['Referral fees'] = (data['8F'] == 'Y').astype(int)
    data['Interest in transacton'] = (data.loc[:, ['8A1', '8A3', '8B2', '8B3']] == 'Y').astype(int).sum(axis=1)
    data['Conflicted advice'] = (data.loc[:, ['8A3', '8B3']] == 'Y').astype(int).sum(axis=1)
    data['Soft Dollars'] = (data['8G1'] == 'Y').astype(int)
    data['Soliciting_clients'] = (pd.to_numeric(data['5B6'], errors='coerce') > 0.).astype(int)

    # Retail clients, decided per row from the value itself. A percentage bucket
    # ('26-50%') is the pre-2017 form; anything else is a count of retail
    # clients, compared against the total client count in 5F2f
    retail_buckets = ['51-75%', 'More than 75%', '76-99%', '100%']
    is_bucket = data['5D1/5D1a'].astype(str).str.contains('%', na=False)
    retail_from_bucket = data['5D1/5D1a'].isin(retail_buckets)
    clients_retail = pd.to_numeric(data['5D1/5D1a'], errors='coerce').fillna(0)
    clients_total = pd.to_numeric(data['5F2f'].replace('0', '1').replace('', '1'), errors='coerce')
    retail_from_count = (clients_retail / clients_total > 0.5)
    data['Retail_clients'] = retail_from_bucket.where(is_bucket, retail_from_count).fillna(False).astype(int)

    # Custody of client assets
    data['Custody'] = ((data.loc[:, '9A1/9A1a':'9B2/9B1b'] == 'Y').astype(int).sum(axis=1) > 0).astype(int)

    # How the adviser is paid
    data['compensation_aum'] = (data['5E1'] == 'Y').astype(int)
    data['compensation_hourly'] = (data['5E2'] == 'Y').astype(int)
    data['compensation_fixed'] = (data['5E4'] == 'Y').astype(int)
    data['compensation_commission'] = (data['5E5'] == 'Y').astype(int)
    data['compensation_performance'] = (data['5E6'] == 'Y').astype(int)
    data['broker_dealer_dummy'] = (data['6A1'] == 'Y').astype(int)

    # Lines of business
    data['Financial_planning'] = (data['5G1'] == 'Y').astype(int)
    data['Port_mgmt_indv_sb'] = (data['5G2'] == 'Y').astype(int)
    data['Port_mgmt_inv_c'] = (data['5G3'] == 'Y').astype(int)
    data['Port_mgmt_pif'] = (data['5G4'] == 'Y').astype(int)
    data['Port_mgmt_bus_insc'] = (data['5G5'] == 'Y').astype(int)
    data['Pension_cs'] = (data['5G6'] == 'Y').astype(int)
    data['Selection_advisers'] = (data['5G7'] == 'Y').astype(int)
    data['Publication_periodicals'] = (data['5G8'] == 'Y').astype(int)
    data['Ratings_pricing'] = (data['5G9'] == 'Y').astype(int)
    data['Market_Timing'] = (data['5G10'] == 'Y').astype(int)
    data['Education_Seminars'] = (data['5G11'] == 'Y').astype(int)
    data['Other'] = (data['5G12'] == 'Y').astype(int)

    # Give the kept columns their reporting names
    data.rename(columns={'1A': 'Legal_name', '1E': 'CRD', '5B4': 'total_employees_advisers',
                         '5B3': 'total_employees_others', '1B1': 'Business_Name',
                         '5F2c': 'dollar_AUM', 'Execution Date': 'Execution_Date',
                         '1F1-State': 'State', '5B2-Number': 'Brokers_in_firm',
                         '5B1': 'emp_advisory_functions', '5A-Number': 'Total_employees',
                         '5F2f': 'Number_clients', '1F1-Street 1': 'Street_One',
                         '1F1-City': 'City', '1F1-Country': 'Country',
                         '1F1-Postal': 'Zipcode'}, inplace=True)

    # Append this file's rows to the output
    data_final = data[keep_columns_final]
    data_final.to_csv(out_path, index=False, encoding="utf-8", header=False, mode="a")
    n_rows += len(data_final)
    print(file, len(data_final))

# Report row count and any skipped files
print("ROWS_OUT", n_rows)
print("FAILED_FILES", len(failed))
for f, why in failed:
    print("  ", f, why)
print("RUN_FINISHED=1")
