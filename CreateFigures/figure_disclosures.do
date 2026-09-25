********************************************************************************
* Builds finestargetacquirer.dta for Figure 1: firm-year disclosure rates and
* fines for targets (target = 1), acquirers (target = 0) and all other firms
* (target = 2). Each merging firm enters in its first merger year.
********************************************************************************
clear

* Load merger pairs, one row per target-acquirer pair
    use data/output/merger_sample, clear
    do "$PKG/_rules/merger_window.do" acquired_year rename "(mergeryear acquirercrds)" "(acquired_year acquirer_crd)"
    do "$PKG/_rules/dedup_key.do" select "target_crd acquirer_crd" "acquired_year" 1

* Reshape to one row per firm, flagged as target or acquirer
    ren (acquirer_crd target_crd) (crd_number0 crd_number1)
    egen id = group(crd_number0 crd_number1 acquired_year)
    reshape long crd_number, i(id) j(target)

* Keep each firm's first merger as target or acquirer
    bys crd: egen minyear = min(acquired_year)
    keep if acquired_year == minyear
    keep crd acquired_year target
    duplicates drop
    do "$PKG/_rules/dedup_key.do" select "crd" "target" _N

* Merge onto the firm-year panel
    merge 1:m crd_number using data/output/firm_year_panel
    do "$PKG/_rules/merge_semantics.do" adv_membership

* Code non-merging firms as target = 2 and compute disclosure rates per 100 employees
    replace target = 2 if target ==.
    gen anyintensityflow = (any_intensity_flow/employees)*100
    gen eganintensityflow = (egan_intensity_flow/employees)*100
    gen anyintensitythree = (any_intensity_three/employees)*100
    gen eganintensitythree = (egan_intensity_three/employees)*100
    gen all_misconduct_egan = (egan_disclosureall/employees)*100
    gen all_misconduct_all = (any_disclosureall/employees)*100

* Keep the figure variables
    do "$PKG/_rules/merge_semantics.do" project_gate_attribute crd_number target year employees anyintensityflow eganintensityflow anyintensitythree eganintensitythree fines_flow fines_flow_sum all_misconduct_egan all_misconduct_all
    duplicates drop

* Express fines in thousands, drop firm-years missing employment or AUM data
* and keep 2009-2020
    replace fines_flow = fines_flow/1000
    replace fines_flow_sum = fines_flow_sum/1000
    do "$PKG/_rules/firm_year_gate.do" gate general
    keep if year >=2009 & year <=2020
    save data/output/finestargetacquirer, replace
