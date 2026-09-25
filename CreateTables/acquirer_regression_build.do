********************************************************************************
* Who becomes an acquirer? Builds the firm-year sample (acquirer_regression.dta) and
* the estimation sample's filing IDs (acquirer_regression_sample.dta) on the filings
* in the target sample. acquirer_regression_table.do estimates Table IV and
* overwrites the tables/acquirer_regression.tex written here.
********************************************************************************


********************************************************************************
* Firm-year sample
********************************************************************************

* List acquirers and their merger years
    do "$PKG/_rules/event_list.do" sample
    do "$PKG/_rules/merger_window.do" mergeryear project "acquirercrds mergeryear"
    duplicates drop
    save data/output/acquiringfirms, replace

* Import firm controls and flag the year before each acquisition
    use data/output/firm_adv_controls, clear
    duplicates drop
    ren organizationcrd acquirercrds
    joinby acquirercrds using data/output/acquiringfirms, unmatched(master)
    drop _m
    gen event_time = (fiscal_year - mergeryear)
    gen acquiring = (event_time == -1)
    do "$PKG/_helpers/restrict_fiscal_2010_2019.do"
    save data/output/acquirer_regression, replace

* Keep one record per firm and fiscal year
    use  data/output/acquirer_regression, clear
    ren acquirercrds crd
    duplicates drop
    do "$PKG/_rules/dedup_key.do" select "crd fiscal_year" "acquiring" _N
    xtset crd fiscal_year

* Add employee and misconduct information and set missing disclosures to zero
    drop year
    gen year = fiscal_year
    ren crd crd_number
    merge 1:1 crd_number year using data/output/firm_year_panel
    keep if _m ==3
    drop _m
    foreach x in  egan_intensity_flow egan_intensity_three any_intensity_flow any_intensity_three {
        replace `x' = 0  if `x' == .
    }
    save data/output/acquirer_regression, replace


********************************************************************************
* Who becomes an acquirer? (Table IV)
********************************************************************************

* Keep firm-years with employees and positive AUM, and compute the share of
* employees with misconduct
    use data/output/acquirer_regression, clear
    do "$PKG/_rules/firm_year_gate.do" gate logged
    gen fraction_bad_three = any_intensity_three/employees
    gen fraction_bad_four = egan_intensity_three/employees

* Log AUM, clients, age and employees, dropping firm-years missing AUM, clients or age
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

* Keep the filings in the target sample so the two samples are the same
    merge 1:1 filingid using data/output/target_regression_sample
    keep if _m ==3
    drop _m

* Label variables
    la var fraction_bad_three_z "Employees with misconduct (All)"
    la var fraction_bad_four_z "Employees with misconduct (Egan)"
    la var ln_aum_z "Ln(Assets under management)"
    la var ln_age_z "Ln(Firm Age)"
    la var ln_clients_z "Ln(Number of clients)"
    la var ln_employees_z "Ln(Number of employees)"
    la var retail_clients "Retail clients"
    la var broker_dealer_dummy "Broker-dealer"

* Define the acquirer indicator and winsorize the misconduct shares
    gen acquirer = (acquiring == 1)
    do "$PKG/_rules/winsorize_last.do" acquirer_final "fraction_bad_three fraction_bad_four"

* How does misconduct affect the probability of acquiring another firm?
* Set the year fixed effect and cluster by firm
    gen year_aum = fiscal_year
    local fe1  year_aum
    local clustervar crd

* Regressor lists for the four specifications
    local indepvar1  acquirer
    local controls  fraction_bad_three_z
    local controls1  fraction_bad_three_z    ///
                     retail_clients ln_aum_z ln_age_z ln_employees_z
    local controls2  fraction_bad_four_z
    local controls3  fraction_bad_four_z ///
                     retail_clients ln_aum_z ln_age_z ln_employees_z

* Advisory-service indicators absorbed as industry fixed effects
    local industry  financial_planning port_mgmt_indv_sb ///
                    port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other

* Estimate the four specifications
    eststo clear
    eststo:  reghdfe `indepvar1' `controls', absorb(`industry' `fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls1', absorb(`industry' `fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls2', absorb(`industry' `fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls3', absorb(`industry' `fe1') vce(cluster `clustervar')

* Export the table
    esttab _all using "tables/acquirer_regression.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(fraction_bad_three_z fraction_bad_four_z) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst

* Keep the filing IDs in the estimation sample so the target regressions use the same filings
    keep filingid
    duplicates drop
    save data/output/acquirer_regression_sample, replace
