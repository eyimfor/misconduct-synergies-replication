********************************************************************************
* Builds all_regression.dta (full firm-year sample) and estimates Table XII
* Panel A, misconduct and AUM per employee (aumemp_withinfirm.tex).
********************************************************************************
clear

* Import the firm ADV controls and merge them onto the firm-year panel
    use data/output/firm_adv_controls, clear
    drop year
    do "$PKG/_rules/employee_timing.do" calendar
    ren organizationcrd crd_number
    merge 1:1 crd_number year using data/output/firm_year_panel
    keep if _m ==3
    drop _m

* Replace missing disclosures with zero
    foreach x in  egan_intensity_flow egan_intensity_three any_intensity_flow any_intensity_three {
        replace `x' = 0  if `x' == .
    }
    save data/output/all_regression, replace

* Generate other measures of misconduct
    use data/output/all_regression, clear
    do "$PKG/_rules/firm_year_gate.do" gate logged
    gen fraction_bad_three = any_intensity_three/employees
    gen fraction_bad_four = egan_intensity_three/employees
    save data/output/all_regression, replace


********************************************************************************
* Employee misconduct and AUM per employee
********************************************************************************

* Set up the panel and the log controls
    use data/output/all_regression, clear
    gen year_aum = fiscal_year
    xtset crd_number year_aum
    do "$PKG/_rules/employee_timing.do" aum_lead
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

* Define the outcome, fixed effects, clustering and control sets
    local fe1  year_aum
    local clustervar crd_number
    local indepvar1  ln_aum_emp
    local controls1  fraction_bad_three_z
    local controls2  fraction_bad_four_z
    local controls3  fraction_bad_three_z   ///
                     retail_clients  ln_age_z ln_employees_z
    local controls4  fraction_bad_four_z  ///
                     retail_clients  ln_age_z  ln_employees_z
    local industry financial_planning port_mgmt_indv_sb ///
                   port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other

* Winsorize the misconduct measures and estimate the four specifications
    do "$PKG/_rules/winsorize_last.do" aum_per_employee_final "fraction_bad_three fraction_bad_four"
    eststo:  reghdfe `indepvar1' `controls1', absorb(`fe1' `clustervar') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls3', absorb(`fe1' `clustervar') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls2', absorb(`fe1' `clustervar') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls4', absorb(`fe1' `clustervar') vce(cluster `clustervar')

* Write the table
    esttab _all using "tables/aumemp_withinfirm.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(fraction_bad_three_z fraction_bad_four_z) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst
