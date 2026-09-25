********************************************************************************
* Who becomes a target? Builds the firm-year sample (target_regression.dta) and a
* first estimation sample (target_regression_sample.dta) used to align the target
* and acquirer samples. target_regression_table.do estimates Table III and
* overwrites the tables/target_regression.tex written here.
********************************************************************************
clear


********************************************************************************
* Target firm-year sample
********************************************************************************

* Targets: first merger year for each target firm
    do "$PKG/_rules/event_list.do" sample
    duplicates drop
    do "$PKG/_rules/merger_window.do" mergeryear project "mergeryear target_crd"
    bys target_crd (mergeryear): keep if _n ==1
    save data/output/targetfirms, replace

* Import firm controls and flag the year before the merger as the target year
    use data/output/firm_adv_controls, clear
    duplicates drop
    ren organizationcrd target_crd
    merge m:1 target_crd using data/output/targetfirms
    drop if _m ==2
    drop _m
    gen event_time = (fiscal_year - mergeryear)
    gen target = (event_time == -1)
    do "$PKG/_helpers/restrict_fiscal_2010_2019.do"
    save data/output/target_regression, replace

* Set up the target firm-year panel
    use  data/output/target_regression, clear
    ren target_crd crd
    duplicates drop
    xtset crd fiscal_year
    drop year
    gen year = fiscal_year

* Add employee and misconduct information (firm-year panel) to targets
    ren crd crd_number
    merge 1:1 crd_number year using data/output/firm_year_panel
    keep if _m ==3
    drop _m

* Replace missing disclosures with zero
    foreach x in  egan_intensity_flow egan_intensity_three any_intensity_flow any_intensity_three  {
        replace `x' = 0  if `x' == .
    }
    save data/output/target_regression, replace


********************************************************************************
* Who becomes a target?
********************************************************************************

* Generate other measures of misconduct
    use data/output/target_regression, clear
    do "$PKG/_rules/firm_year_gate.do" gate logged
    gen fraction_bad_three = any_intensity_three/employees
    gen fraction_bad_four = egan_intensity_three/employees

* Log controls
    gen ln_aum = ln(dollar_aum + 1)
    gen ln_clients = ln(number_clients)
    gen ln_age = ln(adviser_age +1)
    drop if ln_aum == . | ln_clients == . | ln_age == .
    gen ln_employees = ln(employees)

* Standardize control variables
    foreach x in  number_clients adviser_age ///
                  fraction_bad_three fraction_bad_four ///
                  ln_aum ln_clients ln_age ln_employees {
        egen `x'_z = std(`x')
        _crcslbl `x'_z `x'
    }

* Label the regressors
    la var fraction_bad_three_z "Employees with misconduct (All)"
    la var fraction_bad_four_z "Employees with misconduct (Egan)"
    la var ln_aum_z "Ln(Assets under management)"
    la var ln_age_z "Ln(Firm Age)"
    la var ln_clients_z "Ln(Number of clients)"
    la var ln_employees_z "Ln(Number of employees)"
    la var retail_clients "Retail clients"
    la var broker_dealer_dummy "Broker-dealer"

* Scale the target flag to percent, flag firm-years after a target year and winsorize
    replace target = target*100
    gen year_aum = fiscal_year
    sort crd fiscal_year
    bys crd (fiscal_year): gen obs = 1 if target[_n]  == 0 & target[_n-1] == 100
    bys crd (fiscal_year): carryforward obs, replace
    do "$PKG/_rules/winsorize_last.do" target_final "fraction_bad_three fraction_bad_four"

* Specification: how does misconduct affect the probability of acquisition?
    local fe1  year_aum
    local clustervar crd
    local indepvar1  target
    local controls  fraction_bad_three_z
    local controls1  fraction_bad_three_z     ///
                     retail_clients ln_aum_z ln_age_z ln_employees_z
    local controls2  fraction_bad_four_z
    local controls3  fraction_bad_four_z ///
                     retail_clients ln_aum_z ln_age_z ln_employees_z
    local industry  financial_planning port_mgmt_indv_sb  ///
                    port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other

* Estimate the four target regressions
    eststo clear
    eststo:  reghdfe `indepvar1' `controls' , absorb(`industry' `fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls1', absorb(`industry' `fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls2', absorb(`industry' `fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls3', absorb(`industry' `fe1') vce(cluster `clustervar')

* Write the table
    esttab _all using "tables/target_regression.tex", replace label  ///
        star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
        order(fraction_bad_three_z fraction_bad_four_z) ///
        ar2  noomitted  interaction(" $\times$ ") style(tex) ///
        compress nomtitles fragment noconst

* Keep the filing IDs in the estimation sample so the acquirer regressions use the same filings
    keep filingid
    duplicates drop
    save data/output/target_regression_sample, replace
