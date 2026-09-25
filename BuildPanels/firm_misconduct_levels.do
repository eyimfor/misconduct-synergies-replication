********************************************************************************
* Aggregates adviser disclosures to the firm-year level. Writes
* firm_misconduct.dta and firm_year_panel.dta (employees and disclosure
* measures per firm and year).
********************************************************************************
clear

* Build a balanced panel of firms with employee data, from 1996 on
    use data/output/adviser_firm_year, clear
    keep crd_number year
    bys crd_number year: keep if _n == _N
    xtset crd_number year
    keep if year >=1996
    tsfill, full
    save data/output/firm_year_panel, replace

* Add the number of employees to the full firm panel
    use data/output/adviser_firm_year, clear
    bys crd_number year: egen employees = nvals(b_crd_number)
    keep crd_number year employees
    bys crd_number year (employees): keep if _n == _N
    merge 1:1 crd_number year using  data/output/firm_year_panel
    drop if _m ==1
    drop _m
    save data/output/firm_year_panel, replace

* Attach adviser-year disclosures to adviser-firm-year rows
    use data/output/adviser_firm_year, clear
    merge m:1 b_crd_number year using data/output/rr_disclosures_panel
    drop if _m ==2
    drop _m

* Replace missing disclosures with zero; keep one row per adviser-firm-year
    foreach x in  cumulative_disclosures ///
                  cumulative_disclosures_egan egan_intensity any_intensity egan_intensity_sum any_intensity_sum settlement_amountd_sum settlement_amountd{
        replace `x' = 0  if `x' == .
    }
    bys b_crd_number crd_number year (any_intensity): keep if _n == _N

* Sum disclosure intensities to the firm-year level
    bys crd_number year: egen egan_intensity_flow = sum(egan_intensity)
    bys crd_number year: egen egan_intensity_three = sum(egan_intensity_sum)
    bys crd_number year: egen any_intensity_flow = sum(any_intensity)
    bys crd_number year: egen any_intensity_three = sum(any_intensity_sum)

* Count advisers with any disclosure at each firm-year (zero if none)
    bys crd_number year: egen any_disc = nvals(b_crd_number) if cumulative_disclosures >0
    bys crd_number year: egen egan_disc = nvals(b_crd_number) if cumulative_disclosures_egan >0
    bys crd_number year: egen any_disclosureall = max(any_disc)
    bys crd_number year: egen egan_disclosureall = max(egan_disc)
    replace any_disclosureall = 0 if any_disclosureall ==.
    replace egan_disclosureall = 0 if egan_disclosureall ==.

* Sum settlement amounts to the firm-year level
    bys crd_number year: egen fines_flow = sum(settlement_amountd)
    bys crd_number year: egen fines_flow_sum = sum(settlement_amountd_sum)

* Keep one row per firm-year with the firm-level measures
    keep crd_number year egan_intensity_flow egan_intensity_three any_intensity_flow ///
         any_intensity_three any_disclosureall egan_disclosureall fines_flow fines_flow_sum
    bys crd_number year (any_intensity_three): keep if _n == _N
    save data/output/firm_misconduct, replace

* Add misconduct to the firm panel
    use data/output/firm_misconduct, clear
    merge 1:1 crd_number year using data/output/firm_year_panel
    drop if _m ==1
    drop _m

* Replace missing disclosures with zero
    foreach x in  egan_intensity_flow egan_intensity_three any_intensity_flow ///
                  any_intensity_three any_disclosureall egan_disclosureall fines_flow fines_flow_sum {
        replace `x' = 0  if `x' == .
    }

* Average the disclosure flows over the current and previous two years
    foreach x in egan_intensity_flow any_intensity_flow {
        rangestat (mean) `x', interval(year -2 0) by(crd_number)
    }
    keep if year <=2023
    save data/output/firm_year_panel, replace
