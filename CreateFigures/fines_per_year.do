********************************************************************************
* Builds data/output/rr_disclosures_yearly.dta, total settlements per year in $ millions,
* the input to Figure A.1 (aggregate settlements). Keeps positive firm-year fines,
* drops fines above $100 million, and sums by year.
********************************************************************************
clear

* Keep positive firm-year fines up to $100 million
    use data/output/firm_year_panel, clear
    replace fines_flow = 0 if fines_flow <= 0
    drop if fines_flow == 0
    drop if fines_flow > 100000000

* Sum fines by year within the calendar window
    bys year: egen settlement = sum(fines_flow)
    keep year settlement
    duplicates drop
    do "$PKG/_rules/calendar_window.do" settlements

* Convert to $ millions and save
    replace settlement = settlement/1000000
    sort year
    list
    save data/output/rr_disclosures_yearly, replace
