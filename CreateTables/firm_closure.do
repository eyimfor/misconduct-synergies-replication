********************************************************************************
* Table XII, Panel B: employee misconduct and firm closure.
* The outcome is 100 in the year before the firm's closure date (failed_businesses_sec).
* Writes tables/failed.tex.
********************************************************************************
clear

* Load the firm-year regression sample and build the log controls
    do "$PKG/_rules/employee_timing.do" failure_load
    xtset crd_number year_aum
    gen ln_aum_emp = ln(dollar_aum/employees)
    gen ln_clients = ln(number_clients)
    gen ln_age = ln(adviser_age +1)
    gen ln_employees = ln(employees)

* Standardize control variables
    foreach x in  number_clients adviser_age ///
                  fraction_bad_three fraction_bad_four ///
                  ln_clients ln_age ln_employees  {
        egen `x'_z = std(`x')
        _crcslbl `x'_z `x'
    }

* Label the regressors
    la var fraction_bad_three_z "Employees with misconduct (All)"
    la var fraction_bad_four_z "Employees with misconduct (EMS)"
    la var ln_age_z "Ln(Firm Age)"
    la var ln_clients_z "Ln(Number of clients)"
    la var ln_employees_z "Ln(Number of employees)"
    la var retail_clients "Retail clients"
    la var broker_dealer_dummy "Broker-dealer"

* Label the industry (advisory service) indicators
    la var financial_planning "Financial planning"
    la var port_mgmt_indv_sb "Portfolio management individuals"
    la var port_mgmt_inv_c "Portfolio management business"
    la var port_mgmt_bus_insc "Portfolio management other"
    la var pension_cs "Pension consulting"
    la var selection_advisers "Adviser selection"
    la var publication_periodicals "Publication periodicals"
    la var ratings_pricing "Security ratings"
    la var market_timing "Market timing"
    la var other "Other"

* Attach the closure date of failed businesses and flag years up to closure
    cap drop _m
    ren crd organizationcrd
    merge m:1 organizationcrd using data/output/failed_businesses_sec
    drop if _m ==2
    drop _m
    gen failed = ((year_aum <= year(died)) & died != .)


********************************************************************************
* Employee misconduct and firm closure
********************************************************************************

* Set the outcome to 100 in the year before closure
    gen event_time =  year_aum - year(died)
    gen year_died = year(died)
    gen fail = (event_time == -1 & event_time!=.)
    drop failed
    ren fail failed
    replace failed = failed *100

* Define the outcome, fixed effects, clustering and control sets
    local fe1  year_aum
    local clustervar organizationcrd
    local indepvar1  failed
    local controls1  fraction_bad_three_z
    local controls2  fraction_bad_four_z
    local controls3  fraction_bad_three_z   ///
                     retail_clients  ln_age_z ln_employees_z
    local controls4  fraction_bad_four_z  ///
                     retail_clients  ln_age_z  ln_employees_z
    local industry financial_planning port_mgmt_indv_sb ///
                   port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other

* Regress closure on employee misconduct after winsorizing the misconduct measures
    do "$PKG/_rules/winsorize_last.do" firm_closure_final "fraction_bad_three fraction_bad_four"
    eststo:  reghdfe `indepvar1' `controls1', absorb(`fe1'  `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls3', absorb(`fe1'  `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls2', absorb(`fe1'  `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls4', absorb(`fe1'  `industry') vce(cluster `clustervar')

* Write the table
    esttab _all using "tables/failed.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(fraction_bad_three_z fraction_bad_four_z) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst
