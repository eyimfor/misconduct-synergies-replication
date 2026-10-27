********************************************************************************
* Massachusetts 2016 inquiries: flags firms with Massachusetts-registered advisers
* and estimates Appendix Table A.10 (tables/mathing.tex).
********************************************************************************
clear


********************************************************************************
* Firms with Massachusetts-registered advisers
********************************************************************************

* Brokers registered in Massachusetts by 2015
    import delimited ../SecIAPD/output/registration_states_all.csv, clear
    ren individualid b_crd_number
    statastates, name(state)
    keep if _m ==3
    drop _m
    keep if state_fips == 25
    gen year = year(date(regdate, "MDY"))
    keep if year <=2015
    do "$PKG/_rules/dedup_key.do" select "b_crd_number" "year" _N
    save data/output/ma_brokers, replace

* Match the Massachusetts brokers to their 2015 employers
    use data/output/ma_brokers, clear
    keep b_crd_number year
    merge 1:m b_crd_number using data/output/adviser_firm_year
    drop if _m ==1
    gen ma_employee = (_m ==3)
    drop _m
    keep if year ==2015

* Firms that had brokers registered in Massachusetts as of 2015, with their share of employees
    bys crd_number: egen all_employees = nvals(b_crd_number)
    bys crd_number: egen maemployees = nvals(b_crd_number) if ma_employee
    bys crd_number: egen ma_employees = max(maemployees)
    gen fraction_ma = ma_employees/all_employees
    keep crd_number fraction_ma maemployees
    duplicates drop
    do "$PKG/_rules/dedup_key.do" select "crd_number" "maemployees" 1
    replace fraction_ma = 0 if fraction_ma ==.
    replace maemployees = 0 if maemployees ==.
    save data/output/crds_ma_employees, replace


********************************************************************************
* Massachusetts case study: AUM per employee before and after 2016
********************************************************************************

* Load the 2013-2018 firm panel and build log controls
    use data/output/all_regression, clear
    gen year_aum = fiscal_year
    keep if year_aum >=2013&year_aum<=2018
    xtset crd_number year_aum
    gen ln_aum = ln(dollar_aum)
    gen ln_clients = ln(number_clients)
    gen ln_age = ln(adviser_age +1)
    gen ln_employees = ln(employees)
    gen ln_aum_emp = ln(dollar_aum/employees)

* Standardize control variables
    foreach x in  number_clients adviser_age ///
                  fraction_bad_three fraction_bad_four ///
                  ln_aum ln_clients ln_age ln_employees  {
        egen `x'_z = std(`x')
        _crcslbl `x'_z `x'
    }

* Label the controls
    la var fraction_bad_three_z "Employees with misconduct (All)"
    la var fraction_bad_four_z "Employees with misconduct (EMS)"
    la var ln_aum_z "Ln(Assets under management)"
    la var ln_age_z "Ln(Firm Age)"
    la var ln_clients_z "Ln(Number of clients)"
    la var ln_employees_z "Ln(Number of employees)"
    la var retail_clients "Retail clients"
    la var broker_dealer_dummy "Broker-dealer"

* Label the business lines
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

* Treated firms had at least one Massachusetts-registered broker in 2015; post is 2016 onward
    merge m:1 crd_number using data/output/crds_ma_employees
    drop if _m == 2
    drop _m
    replace maemployees = 0 if maemployees == .
    gen treated = (maemployees >0)
    gen post = (year_aum >=2016)

* Treated x post interaction
    gen interaction = treated*post
    la var interaction "Treated X Post"
    la var treated "Treated"

* Specification
    local fe1  year_aum
    local clustervar crd_number
    local indepvar1  ln_aum_emp
    local controls1  interaction  treated ln_employees_z
    local controls2  fraction_bad_four
    local controls3  interaction  treated   ///
                     retail_clients  ln_age_z ln_employees_z
    local controls4  fraction_bad_four  ///
                     retail_clients  ln_age_z  ln_employees_z
    local industry financial_planning port_mgmt_indv_sb ///
                   port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other

* Estimate with year fixed effects, then add firm fixed effects
    eststo clear
    eststo:  reghdfe `indepvar1' `controls1' , absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls3', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls1', absorb(`fe1' `clustervar') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls3', absorb(`fe1' `clustervar') vce(cluster `clustervar')

* Write the table
    esttab _all using "tables/mathing.tex", replace label  ///
        star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
        order(interaction treated) ///
        ar2  noomitted  interaction(" $\times$ ") style(tex) ///
        compress nomtitles fragment noconst
