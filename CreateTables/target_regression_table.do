********************************************************************************
* Table III: who becomes a target, on the filings shared with the Table IV sample.
* Runs after target_regression_build.do and acquirer_regression_build.do, writes
* tables/target_regression.tex and saves target_regression_sample.dta.
********************************************************************************
use data/output/target_regression, clear

* Generate other measures of misconduct
    do "$PKG/_rules/firm_year_gate.do" gate logged
    gen fraction_bad_three = any_intensity_three/employees
    gen fraction_bad_four = egan_intensity_three/employees

* Build the log controls and drop rows missing AUM, clients or age
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

* Keep the filings in the acquirer sample so the target and acquirer samples match
    merge 1:1 filingid using data/output/acquirer_regression_sample // make target and acquirer sample same
    keep if _m ==3
    drop _m

* Label the regressors
    la var fraction_bad_three_z "Employees with misconduct (All)"
    la var fraction_bad_four_z "Employees with misconduct (Egan)"
    la var ln_aum_z "Ln(Assets under management)"
    la var ln_age_z "Ln(Firm Age)"
    la var ln_clients_z "Ln(Number of clients)"
    la var ln_employees_z "Ln(Number of employees)"
    la var retail_clients "Retail clients"
    la var broker_dealer_dummy "Broker-dealer"

* Winsorize the misconduct measures and set the fiscal year as the panel year
    do "$PKG/_rules/winsorize_last.do" target_final_scaled "fraction_bad_three fraction_bad_four"
    gen year_aum = fiscal_year


********************************************************************************
* Misconduct and the probability of acquisition
********************************************************************************

* Define the outcome, fixed effects, clustering and control sets
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

* Estimate the four specifications
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
