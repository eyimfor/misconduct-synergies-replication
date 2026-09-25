********************************************************************************
* Appendix regressions: Tables A.2 (target_regressionind.tex), A.3
* (acquirer_regressionind.tex), A.4 (matching_regressionind.tex, published as
* matching_regressionindustry.tex) and A.6 (post_misc_regsfa.tex, published as
* post_misc_regsfreq.tex).
********************************************************************************


********************************************************************************
* Industry and likelihood of becoming a target (Table A.2)
********************************************************************************

* Load the target sample and build misconduct and size measures
    do "$PKG/_rules/firm_year_gate.do" load logged data/output/target_regression
    gen fraction_bad_three = any_intensity_three/employees
    gen fraction_bad_four = egan_intensity_three/employees
    do "$PKG/_rules/winsorize_last.do" defer_logs
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

* Make the target and acquirer samples the same
    merge 1:1 filingid using data/output/acquirer_regression_sample // make target and acquirer sample same
    keep if _m ==3
    drop _m

* Label controls
    la var fraction_bad_three_z "Employees with misconduct (All)"
    la var fraction_bad_four_z "Employees with misconduct (Egan)"
    la var ln_aum_z "Ln(Assets under management)"
    la var ln_age_z "Ln(Firm Age)"
    la var ln_clients_z "Ln(Number of clients)"
    la var ln_employees_z "Ln(Number of employees)"
    la var retail_clients "Retail clients"
    la var broker_dealer_dummy "Broker-dealer"

* Scale the outcome to percent, flag years after a firm's target year and winsorize
    replace target = target*100
    gen year_aum = fiscal_year
    sort crd fiscal_year
    bys crd (fiscal_year): gen obs = 1 if target[_n]  == 0 & target[_n-1] == 100
    bys crd (fiscal_year): carryforward obs, replace
    do "$PKG/_rules/winsorize_last.do" appendix_target_final "fraction_bad_three fraction_bad_four"

* Label business lines
    la var financial_planning "Financial Planning"
    la var port_mgmt_indv_sb "Individuals Small Business"
    la var port_mgmt_inv_c "Investment Companies"
    la var port_mgmt_bus_insc "Large Businesses"
    la var pension_cs "Pension Consulting"
    la var selection_advisers "Selection Advisers"
    la var publication_periodicals "Publication Periodicals"
    la var ratings_pricing "Ratings and Pricing"
    la var market_timing "Market Timing"
    la var port_mgmt_pif "Pooled Funds"

* How does misconduct affect the probability of acquisition?
    local fe1  fiscal_year
    local clustervar crd
    local indepvar1  target
    local controls  fraction_bad_three_z
    local controls1  fraction_bad_three_z     ///
                     retail_clients ln_aum_z ln_age_z ln_employees_z
    local controls2  fraction_bad_four_z
    local controls3  fraction_bad_four_z ///
                     retail_clients ln_aum_z ln_age_z ln_employees_z
    local industry  financial_planning port_mgmt_indv_sb ///
                    port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other

* Estimate the four specifications
    eststo clear
    eststo:  reghdfe `indepvar1' `controls' `industry', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls1' `industry', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls2' `industry', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls3' `industry' , absorb(`fe1') vce(cluster `clustervar')

* Write the table
    esttab _all using "tables/target_regressionind.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(fraction_bad_three_z fraction_bad_four_z) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst


********************************************************************************
* Industry and likelihood of becoming an acquirer (Table A.3)
********************************************************************************

* Load the acquirer sample and build misconduct and size measures
    do "$PKG/_rules/firm_year_gate.do" load logged data/output/acquirer_regression
    gen fraction_bad_three = any_intensity_three/employees
    gen fraction_bad_four = egan_intensity_three/employees
    do "$PKG/_rules/winsorize_last.do" defer_logs
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

* Make the two samples the same
    merge 1:1 filingid using data/output/target_regression_sample // make the two samples the same
    keep if _m ==3
    drop _m

* Label controls
    la var fraction_bad_three_z "Employees with misconduct (All)"
    la var fraction_bad_four_z "Employees with misconduct (Egan)"
    la var ln_aum_z "Ln(Assets under management)"
    la var ln_age_z "Ln(Firm Age)"
    la var ln_clients_z "Ln(Number of clients)"
    la var ln_employees_z "Ln(Number of employees)"
    la var retail_clients "Retail clients"
    la var broker_dealer_dummy "Broker-dealer"

* Define the outcome and winsorize
    gen acquirer = (acquiring == 1)
    do "$PKG/_rules/winsorize_last.do" appendix_acquirer_final "fraction_bad_three fraction_bad_four"

* Label business lines
    la var financial_planning "Financial Planning"
    la var port_mgmt_indv_sb "Individuals Small Business"
    la var port_mgmt_inv_c "Investment Companies"
    la var port_mgmt_bus_insc "Large Businesses"
    la var pension_cs "Pension Consulting"
    la var selection_advisers "Selection Advisers"
    la var publication_periodicals "Publication Periodicals"
    la var ratings_pricing "Ratings and Pricing"
    la var market_timing "Market Timing"
    la var port_mgmt_pif "Pooled Funds"

* How does misconduct affect the probability of becoming an acquirer?
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
    local industry  financial_planning port_mgmt_indv_sb ///
                    port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other

* Estimate the four specifications
    eststo clear
    eststo:  reghdfe `indepvar1' `controls' `industry', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls1' `industry', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls2' `industry', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls3' `industry', absorb(`fe1') vce(cluster `clustervar')

* Write the table
    esttab _all using "tables/acquirer_regressionind.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(fraction_bad_three_z fraction_bad_four_z) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst


********************************************************************************
* How does industry relate to matching? (Table A.4)
********************************************************************************

* Load the pair-level matching frame
    use data/output/matching_frame_full, clear
    do "$PKG/_helpers/restrict_acquired_year.do"

* Combine size dummies: 1 if target and acquirer are both in the bottom (match1)
* or top (match5) AUM quintile
    bys acquired_year:  egen large_target = xtile(dollar_aum_t), nquant(5)
    bys acquired_year:  egen large_acquirer = xtile(dollar_aum_a), nquant(5)
    gen match1 = (large_target == 1 & large_acquirer ==1)
    gen match5 = (large_target == 5 & large_acquirer ==5)

* Pair similarity in state, clients, size, age and employees
    gen same_state = (state_a == state_t)
    gen retail_clients = (retail_clients_a == retail_clients_t)
    gen aum_ratio = abs(ln(dollar_aum_a) - ln(dollar_aum_t))
    gen age_ratio = abs(ln(adviser_age_a) - ln(adviser_age_t))
    gen employee_ratio = abs(ln(aemployees) - ln(temployees))

* Industry: 1 if target and acquirer share the business line
    gen financial_planning = (financial_planning_a == financial_planning_t)
    gen port_mgmt_indv_sb = (port_mgmt_indv_sb_a == port_mgmt_indv_sb_t)
    gen port_mgmt_inv_c  = (port_mgmt_inv_c_a == port_mgmt_inv_c_t)
    gen port_mgmt_bus_insc = (port_mgmt_bus_insc_a == port_mgmt_bus_insc_t)
    gen pension_cs = (pension_cs_a == pension_cs_t)
    gen selection_advisers = (selection_advisers_a == selection_advisers_t)
    gen publication_periodicals =  (publication_periodicals_a == publication_periodicals_t)
    gen ratings_pricing = (ratings_pricing_a == ratings_pricing_t)
    gen market_timing = (market_timing_a == market_timing_t)
    gen other = (other_a == other_t)
    gen port_mgmt_pif = (port_mgmt_pif_a == port_mgmt_pif_t)

* Label pair variables and define the cluster
    do "$PKG/_rules/winsorize_last.do" pair_labels_tex ""
    la var dummy_two "Acq \& Tar Employees with misconduct (EMS)"
    la var combined_m_z "$|\text{Misconduct} \text{(Acq} - \text{Tar (All))}|$"
    la var combined_two_m_z "$|\text{Misconduct} \text{(Acq} - \text{Tar (Egan)}|$"
    la var aum_ratio_z "$|\text{Ln(AUM Acq)}- \text{Ln(AUM Tar)}|$"
    la var age_ratio_z "$|\text{Ln(Age Acq)}- \text{Ln(Age Tar)}|$"
    la var employee_ratio_z "$|\text{Ln(Emp Acq)} - \text{Ln(Emp Tar)}|$"
    la var retail_clients "Retail clients"
    la var same_state "Same state"
    la var match1 "Target \& Acquirer Small"
    la var match5 "Target \& Acquirer Large"
    egen clustervar = group(target_crd acquirer_crd)

* Label business lines
    la var financial_planning "Financial Planning"
    la var port_mgmt_indv_sb "Individuals Small Business"
    la var port_mgmt_inv_c "Investment Companies"
    la var port_mgmt_bus_insc "Large Businesses"
    la var pension_cs "Pension Consulting"
    la var selection_advisers "Selection Advisers"
    la var publication_periodicals "Publication Periodicals"
    la var ratings_pricing "Ratings and Pricing"
    la var market_timing "Market Timing"
    la var port_mgmt_pif "Pooled Funds"

* How does misconduct relate to which firms match?
    local fe1  acquired_year
    local clustervar clustervar
    local indepvar1  real_match
    local controls  dummy_one
    local controls1  dummy_one    ///
                     retail_clients aum_ratio_z age_ratio_z employee_ratio_z same_state
    local controls2  dummy_two
    local controls3  dummy_two ///
                     retail_clients  aum_ratio_z age_ratio_z employee_ratio_z same_state ///
                     match1 match5
    local industry  financial_planning port_mgmt_indv_sb ///
                    port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other port_mgmt_pif

* Winsorize and estimate the four specifications
    do "$PKG/_rules/winsorize_last.do" a4_pair_final "aum_ratio age_ratio employee_ratio" "`industry'" "`fe1'" "`clustervar'"
    eststo clear
    eststo:  reghdfe `indepvar1' `controls' `industry' if sample, absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls1' `industry' if sample, absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls2' `industry' if sample, absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls3' `industry' if sample, absorb(`fe1') vce(cluster `clustervar')

* Write the table
    esttab _all using "tables/matching_regressionind.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(dummy_one dummy_two) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst


********************************************************************************
* Is the drop in misconduct larger for frequent acquirers? (Table A.6)
********************************************************************************

* Load the event panel, flag frequent acquirers and winsorize
    use data/output/adviser_event_panel, clear
    do "$PKG/_rules/thresholds.do" frequent acquirer_crd acquired_year treated
    do "$PKG/_rules/winsorize_last.do" a6_final "fraction_bad_a_flow fraction_bad_e_flow combined_aumg combined_clg"

* Label regressors
    la var interactionthree "Merged X Post X Frequent"
    la var interaction "Merged X Post"
    la var pastacquirer "Frequent"
    la var treated "Merged"
    la var post "Post"
    la var ln_aum_std "Ln(Assets under management)"
    la var ln_age_z "Ln(Firm Age)"
    la var ln_employees_std "Ln(Number of employees)"
    la var both_retailc "Retail clients"

* Outcomes, controls, fixed effects and clusters
    local fe1  year_aum
    local clustervar cohort
    local indepvar2  fraction_bad_a_flow
    local indepvar4  fraction_bad_e_flow
    local controls   interactionthree interaction treated post pastacquirer
    local controls2   interactionthree interaction treated post pastacquirer both_retailc ln_aum_std ln_age_z ln_employees_std

* Estimate the four specifications
    eststo clear
    eststo:  reghdfe `indepvar2' `controls', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar2' `controls2', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar4' `controls', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar4' `controls2', absorb(`fe1') vce(cluster `clustervar')

* Write the table
    esttab _all using "tables/post_misc_regsfa.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(interactionthree interaction treated post) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst
