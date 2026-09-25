********************************************************************************
* Table IV: who becomes an acquirer, on the filings also in the Table III sample.
* Writes tables/acquirer_regression.tex and saves acquirer_regression_sample.dta.
********************************************************************************
use data/output/acquirer_regression, clear

* Drop firm-years missing Form ADV or employment data or with zero AUM, then
* build the misconduct measures (share of employees with misconduct)
    do "$PKG/_rules/firm_year_gate.do" gate logged
    gen fraction_bad_three = any_intensity_three/employees
    gen fraction_bad_four = egan_intensity_three/employees

* Log size and age controls
    gen ln_aum = ln(dollar_aum + 1)
    gen ln_clients = ln(number_clients)
    gen ln_age = ln(adviser_age +1)
    drop if ln_aum == . | ln_clients == . | ln_age == .
    gen ln_employees = ln(employees)

* Standardize the control variables
    foreach x in  number_clients adviser_age ///
                  fraction_bad_three fraction_bad_four ///
                  ln_aum ln_clients ln_age ln_employees {
        egen `x'_z = std(`x')
        _crcslbl `x'_z `x'
    }

* Keep the filings also in the target regression sample
    merge 1:1 filingid using data/output/target_regression_sample // make the two samples the same
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

* Define the outcome (in percent), keep its estimation sample, winsorize and standardize
    gen acquirer = (acquiring == 1)
    do "$PKG/_rules/winsorize_last.do" acquirer_final "fraction_bad_three fraction_bad_four"


********************************************************************************
* How does misconduct affect the probability of becoming an acquirer?
********************************************************************************

* Outcome, fixed effects, clustering and control sets
    gen year_aum = fiscal_year
    local fe1  year_aum
    local clustervar crd

    local indepvar1  acquirer
    local controls  fraction_bad_three_z
    local controls1  fraction_bad_three_z    ///
                     retail_clients ln_aum_z ln_age_z ln_employees_z
    local controls2  fraction_bad_four_z
    local controls3  fraction_bad_four_z ///
                     retail_clients ln_aum_z ln_age_z ln_employees_z

* Industry fixed effects: advisory services
    local industry  financial_planning port_mgmt_indv_sb ///
                    port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other

* Estimate the four columns
    eststo clear
    eststo:  reghdfe `indepvar1' `controls', absorb(`industry' `fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls1', absorb(`industry' `fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls2', absorb(`industry' `fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls3', absorb(`industry' `fe1') vce(cluster `clustervar')

* Write the table
    esttab _all using "tables/acquirer_regression.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(fraction_bad_three_z fraction_bad_four_z) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst

* Keep the filing IDs in the estimation sample
    keep filingid
    duplicates drop
    save data/output/acquirer_regression_sample, replace
