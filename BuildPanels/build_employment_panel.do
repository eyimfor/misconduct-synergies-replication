********************************************************************************
* Imports BrokerCheck and IAPD employment spells and builds
* adviser_registration_spells.dta, adviser_year.dta and adviser_firm_year.dta.
* The input, employmentdataall_2024.csv, is written by
* CollectData/_1_combine_employment.py from the 2020, 2022 and 2024 scrapes.
********************************************************************************
clear

* Import the BrokerCheck registration spells and convert their dates
    import delimited ../SecIAPD/output/employmentdataall_2024.csv, clear
    gen registrationBeginDate = date(registrationbegindate, "YMD")
    gen registrationEndDate = date(registrationenddate, "YMD")
    format registrationBeginDate registrationEndDate %td
    ren (individualid firmid) (b_crd_number crd_number)
    save data/output/adviser_registration_spells, replace

* Build an adviser-year dataset spanning each adviser's first to last registration year
    use data/output/adviser_registration_spells, clear
    bys b_crd_number: egen max_year = max(year(registrationEndDate))
    bys b_crd_number: egen min_year = min(year(registrationBeginDate))
    keep b_crd_number min_year max_year
    duplicates drop
    expand max_year -min_year +1
    bys b_crd_number: gen year = min_year +_n-1
    keep b_crd_number year
    duplicates drop
    save data/output/adviser_year, replace

* Add years to the employment spells to form the adviser-firm-year dataset
    use data/output/adviser_registration_spells, clear
    gen regis_start = year(registrationBeginDate)
    gen regis_end = year(registrationEndDate)
    rangejoin year regis_start regis_end using data/output/adviser_year, by(b_crd_number)
    drop registrationBeginDate registrationEndDate regis_start regis_end
    drop if year == .
    save data/output/adviser_firm_year, replace
