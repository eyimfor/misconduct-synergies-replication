********************************************************************************
* Assigns each Form ADV filing to a firm fiscal year and builds
* adv_filing_dates.dta, the firm-year calendar of data and control windows
* used by the firm-year panels. Fiscal year and fiscal month define the data
* intervals.
********************************************************************************
clear


********************************************************************************
* Firm-year calendar
********************************************************************************

* Save the submission date of each filing
    import delimited data/input/all_controls_2023, varnames(1) clear
    keep filingid crd execution_date
    save data/output/filingidsubmissiondates, replace

* Find each firm's first and last filing year
    use data/output/filingidsubmissiondates, clear
    gen first_year = year(date(execution_date, "MDY"))
    bys crd: egen last_year = max(first_year)
    bys crd (first_year): keep if _n ==1
    destring crd, replace force
    keep crd first_year last_year

* Create a panel that goes from the earliest filing to the latest filing year
    gen year = first_year
    tsset crd year
    tsfill, full
    bys crd: egen year_one = max(first_year)
    bys crd: egen year_last = max(last_year)
    drop first_year last_year
    keep if year >=year_one & year <= year_last
    save data/output/adv_filing_dates, replace

* Attach the fiscal month reported on each filing
    use data/input/fiscal_month2023, clear
    destring filingid, replace force
    merge 1:m filingid using data/output/filingidsubmissiondates
    keep if _m ==3
    drop _m
    destring filingid crd, replace
    gen year = year(date(execution_date, "MDY"))
    gen date_submitted = date(execution_date, "MDY")

* Pin one fiscal month per firm-year and add it to the calendar
    do "$PKG/_rules/filing_pins.do" fiscal_month
    keep crd month_fiscal_year year
    duplicates drop
    merge 1:1 crd year using data/output/adv_filing_dates
    drop _m
    ren month_fiscal_year fiscal_month
    bys crd (year): carryforward fiscal_month, replace // for fiscal months that are missing, use the one from the previous year
    save data/output/adv_filing_dates, replace

* Create the data and control windows for submissions
    use data/output/adv_filing_dates, clear
    drop year_one year_last
    gen month = mofd(date(fiscal_month, "M"))
    replace month = month +1
    gen data_to = ym(year, month)
    gen data_from = ym(year-1, month)
    replace data_from = data_from+1
    gen controls_to = data_from - 1
    gen controls_from = data_from - 12
    format data_to data_from controls_from controls_to %tm
    save data/output/adv_filing_dates, replace


********************************************************************************
* Fiscal year of each filing, based on its submission date
********************************************************************************

* Save the submission date of each filing as a date
    use data/output/filingidsubmissiondates, clear
    destring filingid crd, replace
    keep filingid crd execution_date
    gen date_submitted = date(execution_date, "MDY")
    drop execution_date
    format date_submitted %td
    save data/output/submissiondates, replace

* Attach the month after each filing's fiscal month
    use data/input/fiscal_month2023, clear
    gen month = mofd(date(month_fiscal_year, "M"))
    replace month = month +1
    destring filingid, replace
    keep filingid month
    duplicates drop
    ren month fiscalmonth
    merge 1:m filingid using data/output/submissiondates
    keep if _m ==3
    drop _m
    duplicates drop

* Assign the fiscal year from the submission month
    gen fiscalmonth_m = ym(year(date_submitted), fiscalmonth)
    gen month_submitted = mofd(date_submitted)
    format fiscalmonth_m month_submitted %tm
    gen fiscal_year = year(date_submitted) if ((month_submitted>=fiscalmonth_m) & (month_submitted<=fiscalmonth_m+12))
    replace fiscal_year = year(date_submitted) - 1 if (month_submitted<fiscalmonth_m)

* Keep one filing per firm-fiscal-year: the last one submitted. When a firm
* files twice on the same day, date_submitted cannot order the filings, so
* filingid is added as a second sort key to make the choice the same on every
* run. This tiebreak is stable but arbitrary; filingid does not follow
* submission order.
* $pin_filing_tie: 1 = sort on date_submitted and filingid,
* 0 = date_submitted only.
    if $pin_filing_tie == 1 {
        bys crd fiscal_year (date_submitted filingid): keep if _n == _N
    }
    else {
        bys crd fiscal_year (date_submitted): keep if _n == _N
    }

* Attach the firm-year calendar to each kept filing
    gen year  = year(date_submitted)
    keep filingid crd date_submitted fiscal_year year
    merge m:1 crd year using data/output/adv_filing_dates
    keep if _m ==3
    drop _m
    drop month
    save data/output/adv_filing_dates, replace

* Erase intermediate files
    erase data/output/filingidsubmissiondates.dta
    erase data/output/submissiondates.dta
