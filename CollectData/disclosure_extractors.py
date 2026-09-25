"""Disclosure extraction and consolidation for the BrokerCheck/IAPD scrapes.

_0_onepass_extract.py calls write_to_csv with the nine extract_* functions to write one
CSV per disclosure type, headed by disclosure_headers. _1_consolidate_disclosures.py then
calls remove_duplicates_and_save and consolidate_data to stack the types into
disclosures_2024.csv.
"""

import os
import re

import pandas as pd


def sanitize_filename(text):
    """Remove spaces and special characters, replace with underscores."""
    return re.sub(r'\W+', '_', text)  # Replace non-word characters with underscores


def write_to_csv(data, writer, disclosure_type, extract_function):
    # Write one row per disclosure of the given type: individual id, then the extracted fields
    if "disclosures" in data:
        disclosures = data["disclosures"]
        for disclosure in disclosures:
            if 'disclosureType' in disclosure:
                if disclosure['disclosureType'] == disclosure_type:
                    individualId = data['basicInformation'].get('individualId', '')
                    row = [individualId] + extract_function(disclosure)
                    writer.writerow(row)


def get_nested_field(data, field):
    # Follow a list of keys into nested data; return "" when a key is missing
    if type(field) is list:
        for key in field:
            try:
                data = data[key]
            except (KeyError, TypeError, IndexError):
                return ""
    else:
        return data.get(field, "")
    return data


# ---- One extractor per disclosure type ----------------------------------------

def extract_civilbond(employment):
    fields = [
        "eventDate",
        "disclosureType",
        "disclosureResolution",
        "bcCtgryType",
        "iaCtgryType",
        ['disclosureDetail', "Disposition"],
        ['disclosureDetail', "Payout Detail"],
        ['disclosureDetail', "Payout Amount"],
        ['disclosureDetail', 'Broker Comment']
    ]
    return [get_nested_field(employment, field) for field in fields]


def extract_investigation(employment):
    fields = [
        "eventDate",
        "disclosureType",
        "disclosureResolution",
        "bcCtgryType",
        "iaCtgryType",
        ['disclosureDetail', "Initiated By"],
        ['disclosureDetail', "Description of Investigation"],
        ['disclosureDetail', 'Broker Comment']
    ]
    return [get_nested_field(employment, field) for field in fields]


def extract_civil(employment):
    fields = [
        "eventDate",
        "disclosureType",
        "disclosureResolution",
        "bcCtgryType",
        "iaCtgryType",
        ['disclosureDetail', "Initiated By"],
        ['disclosureDetail', "Allegations"],
        ['disclosureDetail', "Resolution"],
        ['disclosureDetail', 'SanctionDetails', 0, "Sanctions"],
        ['disclosureDetail', 'SanctionDetails', 0, 'SanctionDetails', 0, "Amount"],
        ['disclosureDetail', "Sanctions"],
        ['disclosureDetail', 'Broker Comment']
    ]
    return [get_nested_field(employment, field) for field in fields]


def extract_judgementlien(employment):
    fields = [
        "eventDate",
        "disclosureType",
        "disclosureResolution",
        "bcCtgryType",
        "iaCtgryType",
        ['disclosureDetail', "Judgment/Lien Amount"],
        ['disclosureDetail', "Judgment/Lien Type"],
        ['disclosureDetail', "Broker Comment"]
    ]
    return [get_nested_field(employment, field) for field in fields]


def extract_sepallegation(employment):
    fields = [
        "eventDate",
        "disclosureType",
        "disclosureResolution",
        "bcCtgryType",
        "iaCtgryType",
        ['disclosureDetail', "Firm Name"],
        ['disclosureDetail', "Termination Type"],
        ['disclosureDetail', 'Allegations'],
        ['disclosureDetail', 'Broker Comment']
    ]
    return [get_nested_field(employment, field) for field in fields]


def extract_financial(employment):
    fields = [
        "eventDate",
        "disclosureType",
        "disclosureResolution",
        "bcCtgryType",
        "iaCtgryType",
        ['disclosureDetail', "Type"],
        ['disclosureDetail', "Disposition"],
        ['disclosureDetail', 'Broker Comment']
    ]
    return [get_nested_field(employment, field) for field in fields]


def extract_customerdispute(employment):
    fields = [
        "eventDate",
        "disclosureType",
        "disclosureResolution",
        "bcCtgryType",
        "iaCtgryType",
        ['disclosureDetail', "Allegations"],
        ['disclosureDetail', "Damage Amount Requested"],
        ['disclosureDetail', "Settlement Amount"],
        ['disclosureDetail', 'arbitrationClaimFiledDetail'],
        ['disclosureDetail', 'Broker Comment']
    ]
    return [get_nested_field(employment, field) for field in fields]


def extract_criminal(employment):
    fields = [
        "eventDate",
        "disclosureType",
        "disclosureResolution",
        "bcCtgryType",
        "iaCtgryType",
        ['disclosureDetail', "criminalCharges", 0, "Charges"],
        ['disclosureDetail', 'criminalCharges', 0, "Charge Type"],
        ['disclosureDetail', 'criminalCharges', 0, 'Disposition'],
        ['disclosureDetail', 'Broker Comment']
    ]
    return [get_nested_field(employment, field) for field in fields]


def extract_regulatory(employment):
    fields = [
        "eventDate",
        "disclosureType",
        "disclosureResolution",
        "bcCtgryType",
        "iaCtgryType",
        ['disclosureDetail', "DocketNumberFDA"],
        ['disclosureDetail', "DocketNumberAAO"],
        ['disclosureDetail', "Initiated By"],
        ['disclosureDetail', "Allegations"],
        ['disclosureDetail', "Resolution"],
        ['disclosureDetail', 'SanctionDetails', 0, "Sanctions"],
        ['disclosureDetail', 'SanctionDetails', 0, 'SanctionDetails', 0, "Amount"],
        ['disclosureDetail', "Sanction Details"],
        ['disclosureDetail', 'Broker Comment']
    ]
    return [get_nested_field(employment, field) for field in fields]


# ---- Type-to-extractor map and CSV headers ------------------------------------

# Mapping of disclosure types to their respective extract functions
disclosure_type_functions = {
    'Regulatory': extract_regulatory,
    'Criminal': extract_criminal,
    'Customer Dispute': extract_customerdispute,
    'Financial': extract_financial,
    'Employment Separation After Allegations': extract_sepallegation,
    'Judgment / Lien': extract_judgementlien,
    'Civil': extract_civil,
    'Investigation': extract_investigation,
    'Civil Bond': extract_civilbond
}

# Headers for each disclosure type
disclosure_headers = {
    'Regulatory': [
        "individualId", "eventDate", "disclosureType", "disclosureResolution",
        "bcCtgryType", "iaCtgryType", "DocketNumberFDA", "DocketNumberAAO",
        "InitiatedBy", "Allegations", "Resolution", "Sanctions",
        "DamagesGranted", "SanctionDetails", "BrokerComment"
    ],
    'Criminal': [
        "individualId", "eventDate", "disclosureType", "disclosureResolution",
        "bcCtgryType", "iaCtgryType", "Charges", "Charge Type",
        "Disposition", "BrokerComment"
    ],
    'Customer Dispute': [
        "individualId", "eventDate", "disclosureType", "disclosureResolution",
        "bcCtgryType", "iaCtgryType", "Allegations", "Damage Amount Requested",
        "Settlement Amount", "arbitrationClaimFiledDetail", "Broker Comment"
    ],
    'Financial': [
        "individualId", "eventDate", "disclosureType", "disclosureResolution",
        "bcCtgryType", "iaCtgryType", "Type",
        "Disposition", "BrokerComment"
    ],
    'Employment Separation After Allegations': [
        "individualId", "eventDate", "disclosureType", "disclosureResolution",
        "bcCtgryType", "iaCtgryType", "Firm Name", "Termination Type",
        "Allegations", "BrokerComment"
    ],
    'Judgment / Lien': [
        "individualId", "eventDate", "disclosureType", "disclosureResolution",
        "bcCtgryType", "iaCtgryType", "Judgment/Lien Amount", "Judgment/Lien Type",
        "BrokerComment"
    ],
    'Civil': [
        "individualId", "eventDate", "disclosureType", "disclosureResolution",
        "bcCtgryType", "iaCtgryType", "Initiated By", "Allegations",
        "Resolution", "Sanctions", "Amount", 'Sanctions2', "BrokerComment"
    ],
    'Investigation': [
        "individualId", "eventDate", "disclosureType", "disclosureResolution",
        "bcCtgryType", "iaCtgryType", "Initiated By", "Description of Investigation",
        "BrokerComment"
    ],
    'Civil Bond': [
        "individualId", "eventDate", "disclosureType", "disclosureResolution",
        "bcCtgryType", "iaCtgryType", "Disposition", "PayoutDetail",
        "PayoutAmount", "BrokerComment"
    ]
}


def remove_duplicates_and_save(output_folder):
    # List only CSV files starting with "disclosures" in the output folder
    csv_files = [f for f in os.listdir(output_folder) if f.startswith('disclosures') and f.endswith('.csv')]

    for file in csv_files:
        file_path = os.path.join(output_folder, file)
        print(f"Processing {file}...")
        # Drop duplicate rows and save the file in place
        df = pd.read_csv(file_path, low_memory=False)
        df = df.drop_duplicates()
        df.to_csv(file_path, index=False)
        print(f"{file} has been updated.")


def consolidate_data(output_folder):
    # Columns of the consolidated table
    final_columns = ["individualId", "eventDate", "disclosureType", "disclosureResolution", "DamagesAmount"]
    final_df = pd.DataFrame(columns=final_columns)

    # Mapping of file prefixes to their specific 'amount' column name
    damages_column_mapping = {
        'disclosuresRegulatory': 'DamagesGranted',
        'disclosuresCustomer_Dispute': 'Damage Amount Requested',
        'disclosuresCivil': 'Amount',
        'disclosuresCivil_Bond': 'DamagesGranted',
        'disclosuresCriminal': 'DamagesGranted',
        'disclosuresFinancial': 'DamagesGranted',
        'disclosuresInvestigation': 'DamagesGranted',
        'disclosuresJudgment_Lien': 'DamagesGranted',
        'disclosuresEmployment_Separation_After_Allegations': 'DamagesGranted'
    }

    # Stack every type's CSV files into one table
    for prefix, amount_column in damages_column_mapping.items():
        csv_files = [f for f in os.listdir(output_folder) if f.startswith(prefix) and f.endswith('.csv')]

        for file in csv_files:
            file_path = os.path.join(output_folder, file)
            df = pd.read_csv(file_path)

            # If the file lacks its amount column, add it with all values set to zero
            if amount_column not in df.columns:
                df[amount_column] = 0

            # Keep the common columns, renamed to a unified amount name and ordered
            columns = ["individualId", "eventDate", "disclosureType", "disclosureResolution", amount_column]
            df = df[columns].drop_duplicates()
            df.rename(columns={amount_column: "DamagesAmount"}, inplace=True)
            df = df[["individualId", "eventDate", "disclosureType", "disclosureResolution", "DamagesAmount"]]
            final_df = pd.concat([final_df, df], ignore_index=True)

    # Drop duplicates based on the defined columns
    final_df = final_df.drop_duplicates(subset=["individualId", "eventDate", "disclosureType", "disclosureResolution", "DamagesAmount"])

    return final_df
