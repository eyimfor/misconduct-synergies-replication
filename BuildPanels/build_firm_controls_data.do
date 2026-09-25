********************************************************************************
* Builds firm_adv_controls (Form ADV firm controls by filing year) and
* businesslines (line-of-business classification of each firm-year).
********************************************************************************
clear


********************************************************************************
* Form ADV controls by firm and fiscal year (firm_adv_controls)
********************************************************************************

* Import the Form ADV controls and keep filings with a filing date
    import delimited data/input/all_controls_2023, varnames(1) clear
    duplicates drop
    merge 1:1 filingid using data/output/adv_filing_dates
    keep if _m ==3
    drop _m

* Record each firm's first filing year, set the fiscal year and save
    bys crd: egen firstyear = min(year)
    do "$PKG/_rules/calendar_window.do" adv_fiscal
    save data/output/firm_adv_controls, replace


********************************************************************************
* Lines of business (businesslines)
********************************************************************************

* Load the filings again to classify lines of business
    import delimited data/input/all_controls_2023, clear
    do "$PKG/_rules/filing_pins.do" industry_date
    duplicates drop

* Classify each filing by its combination of lines of business
    gen industry = 1 if (port_mgmt_indv_sb==1) & (port_mgmt_inv_c==0& port_mgmt_pif==0& port_mgmt_bus_insc==0& financial_planning==0)
    replace industry = 2 if (port_mgmt_pif==1) & (port_mgmt_indv_sb==0& port_mgmt_inv_c==0& port_mgmt_bus_insc==0& financial_planning==0)
    egen portfolio_mgmt = rowtotal(port_mgmt_indv_sb port_mgmt_inv_c port_mgmt_pif port_mgmt_bus_insc)
    replace industry = 3 if (portfolio_mgmt>=2) & (financial_planning==0)
    replace industry = 4 if (portfolio_mgmt>=1) & (financial_planning==1)
    replace industry = 5 if (portfolio_mgmt==0) & (financial_planning==0)
    replace industry = 6 if industry ==.

* Keep one classification per firm-year and save
    do "$PKG/_rules/filing_pins.do" industry_last
    keep crd year industry
    save data/output/businesslines, replace
