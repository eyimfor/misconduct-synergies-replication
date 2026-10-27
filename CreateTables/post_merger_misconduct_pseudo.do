********************************************************************************
* Builds the pseudo-merger panels used for Table VIII and as the control group
* in Tables IX and A.7 and Figure 4: adviser-level event_panel_pseudo.dta and
* pair-year postmergercombinedfirmcf.dta.
********************************************************************************
clear

* Import and clean data: pseudo targets (count 1) and pseudo acquirers (count 2)
    use data/output/merger_pairs_long, clear
    keep if count ==1 | count == 2
    gen target = (count == 1)
    keep id crd acquired_year target
    do "$PKG/_helpers/restrict_acquired_year.do"

* Keep pairs where both the pseudo target and the pseudo acquirer are present
    bys id: egen obs = nvals(crd)
    keep if obs == 2 // both the pseudo target and the pseudo acquirer must be present
    drop obs
    save data/output_robust/mergercf, replace

* Misconduct of the pseudo target and acquirer: keep brokers who worked for
* either firm
    use data/output_robust/mergercf, clear
    ren crd crd_number
    joinby crd_number using data/output/adviser_firm_year

* First year each adviser appears at the firm
    bys b_crd_number crd_number: egen min_year = min(year)
    keep id b_crd_number crd_number min_year target year
    duplicates drop
    save data/output_robust/counterfactual_employeesrealcf, replace

* Panel of brokers that worked for the pseudo target or acquiring firm
    use data/output_robust/counterfactual_employeesrealcf, clear
    ren crd_number crd
    keep b_crd_number crd year
    duplicates drop
    ren crd crd_number
    save data/output_robust/counterfactual_employeesrealcfp, replace

* Next-year employer: separation and left-industry indicators
    use data/output_robust/counterfactual_employeesrealcfp, clear
    replace year = year+1
    ren crd_number crd_number_prev
    joinby b_crd_number year using data/output/adviser_firm_year, unmatched(master)
    drop _m
    gen separation = (crd_number!=crd_number_prev)
    sort b_crd_number year
    gen left_industry = (crd_number == .)

* Return to the current year and keep one row per adviser, firm and year
    ren crd_number_prev crd
    keep b_crd_number crd year separation left_industry
    replace year = year - 1
    duplicates drop
    do "$PKG/_rules/dedup_key.do" select "b_crd_number crd year" "separation" 1
    save data/output_robust/employment_counterfactualrealcf, replace

* Add misconduct data
    use data/output/rr_disclosures_panel, clear
    merge 1:m b_crd_number year using data/output_robust/employment_counterfactualrealcf
    drop if _m ==1 // _m ==2 is brokers with no misconduct ever
    drop _m

* Replace missing disclosures with zero
    foreach x in settlement_amountd cumulative_disclosures ///
                 cumulative_disclosures_egan egan_intensity any_intensity any_intensity_sum egan_intensity_sum {
        replace `x' = 0  if `x' == .
    }
    save data/output_robust/employment_counterfactual_disclosuresrealcf, replace

* Get data ready for regressions: attach each adviser's event, role and
* disclosures
    use data/output_robust/counterfactual_employeesrealcf, clear
    ren crd_number crd
    merge m:1 id crd using data/output_robust/mergercf
    keep if _m ==3
    drop _m
    keep id crd target b_crd_number acquired_year
    duplicates drop
    joinby crd b_crd_number using data/output_robust/employment_counterfactual_disclosuresrealcf
    save data/output_robust/event_panel_pseudo, replace


********************************************************************************
* Pseudo mergers: disclosure measures per 100 employees of the combined firm
********************************************************************************

* Employee count and disclosure totals per event and year
    use data/output_robust/event_panel_pseudo, clear
    bys id year: gen employees = _N
    bys id year: egen all_intensity_flow1 = sum(any_intensity)
    bys id year: egen egan_intensity_flow1 = sum(egan_intensity)
    bys id year: egen all_intensity_flow = sum(any_intensity_sum)
    bys id year: egen egan_intensity_flow = sum(egan_intensity_sum)
    bys id year: egen all_intensity_flowN = sum(cumulative_disclosures)
    bys id year: egen egan_intensity_flowN = sum(cumulative_disclosures_egan)

* Scale each total to disclosures per 100 employees
    foreach x in all_intensity_flow1 egan_intensity_flow1 all_intensity_flow ///
                 egan_intensity_flow all_intensity_flowN egan_intensity_flowN{
        replace `x' = 0 if `x' ==.
        replace `x' = ((`x')/employees)*100
    }

* Keep one row per event and year, with event time and a post-merger flag
    gen event_time = year - acquired_year
    keep id year event_time all_intensity_flow1 egan_intensity_flow1 ///
         all_intensity_flow egan_intensity_flow all_intensity_flowN egan_intensity_flowN employees acquired_year
    duplicates drop
    ren (all_intensity_flow egan_intensity_flow) (any_misconduct egan_misconduct)
    do "$PKG/_rules/calendar_window.do" adviser_event
    gen post_merger = (event_time>=0)
    save data/output_robust/postmergercombinedfirmcf, replace
