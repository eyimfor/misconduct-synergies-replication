********************************************************************************
* Table VI: do targets and acquirers match on misconduct, within state and a one-year window?
* Firms are located by the states where their employees work, not by headquarters.
* A target is paired with any acquirer active within one year of its acquisition. The regressor
* is the Misconduct Distance Rank within the target's candidate set, as in Table V.
* Writes tables/matching_regression_TimeWindow2023.tex and saves matching_sample_timewin.dta,
* the estimation sample with the rank, which matching_alt_measures.do (Table A.5) reads.
********************************************************************************
clear


********************************************************************************
* Step 1: employee locations from the employment data
********************************************************************************

* Import the raw employment data and clean the registration dates
    import delimited ../SecIAPD/output/employmentdataall_2024.csv, clear
    gen registrationBeginDate = date(registrationbegindate, "YMD")
    gen registrationEndDate = date(registrationenddate, "YMD")
    format registrationBeginDate registrationEndDate %td
    ren (individualid firmid) (b_crd_number crd_number)
    save data/output/registrationhistory_temp, replace

* Build a broker-year dataset spanning each broker's first to last registration year
    use data/output/registrationhistory_temp, clear
    bys b_crd_number: egen max_year = max(year(registrationEndDate))
    bys b_crd_number: egen min_year = min(year(registrationBeginDate))
    keep b_crd_number min_year max_year
    duplicates drop
    expand max_year - min_year + 1
    bys b_crd_number: gen year = min_year + _n - 1
    keep b_crd_number year
    duplicates drop
    save data/output/brokeryear_temp, replace

* Create a broker-firm-year panel with locations from the registration spells
    use data/output/registrationhistory_temp, clear
    gen regis_start = year(registrationBeginDate)
    gen regis_end = year(registrationEndDate)
    rangejoin year regis_start regis_end using data/output/brokeryear_temp, by(b_crd_number)
    drop registrationBeginDate registrationEndDate regis_start regis_end
    drop if year == .

* Keep the longest tenure for each broker-firm-year
    gen tenure = year - year(date(registrationbegindate, "YMD")) + 1
    do "$PKG/_rules/dedup_key.do" select "b_crd_number crd_number year" "tenure" _N
    save data/output/brokeryearemployment_temp, replace

* Count employees by state for each firm-year
* Every state where the firm has at least one employee is kept, so two firms can match
* on any state they share.
    use data/output/brokeryearemployment_temp, clear
    bys crd_number year state: egen employees_in_state = count(b_crd_number)
    keep crd_number year state employees_in_state
    duplicates drop
    save data/output/firmyear_employeestate, replace


********************************************************************************
* Step 2: merger data
********************************************************************************

* Load the targets and acquirers in the M&A market, one acquirer per target and merger year
    do "$PKG/_rules/merger_window.do" mergeryear load "data/output/merger_sample"
    do "$PKG/_rules/dedup_key.do" select "target_crd mergeryear" "acquirercrds" _N
    keep acquirercrds mergeryear target_crd
    ren (acquirercrds mergeryear) (acquirer_crd acquired_year)
    duplicates drop
    save data/output/merger_data_small_timewin, replace


********************************************************************************
* Step 3: real and counterfactual merger pairs
* Candidate pairs share an employee state and have acquisition years at most one year apart.
********************************************************************************

* List the actual targets with their employee states, from the firm-year-state panel
    use data/output/firmyear_employeestate, clear
    ren crd_number target_crd
    ren employees_in_state target_employees_in_state
    ren state state_match
    gen acquired_year = year + 1

* Keep only targets that were actually acquired
    merge m:1 target_crd acquired_year using data/output/merger_data_small_timewin, ///
          keepusing(target_crd acquired_year)
    keep if _merge == 3
    drop _merge year
    ren acquired_year target_acquired_year
    duplicates drop
    save data/output/targets_timewin_temp, replace

* List all acquirers with their employee states, keeping only firms that were acquirers
* in the sample
    use data/output/firmyear_employeestate, clear
    ren crd_number acquirer_crd
    ren employees_in_state acquirer_employees_in_state
    ren state state_match
    gen acquired_year = year + 1
    joinby acquirer_crd acquired_year using data/output/merger_data_small_timewin
    keep acquirer_crd state_match year acquirer_employees_in_state acquired_year
    ren acquired_year acquirer_acquired_year
    drop year
    duplicates drop
    save data/output/acquirers_timewin_temp, replace

* Count the target-state-year combinations (diagnostic)
    use data/output/targets_timewin_temp, clear
    count
    local n_target_state_year = r(N)

* Join every acquirer in the target's state (any year), then keep pairs whose
* acquisition years differ by at most one
    joinby state_match using data/output/acquirers_timewin_temp
    gen year_diff = abs(target_acquired_year - acquirer_acquired_year)
    keep if year_diff <= 1

* Count the rows after the join and the time filter (diagnostic)
    count
    local n_after_joinby = r(N)

* For each pair, keep only the shared state with the most combined employees
    gen combined_employees = target_employees_in_state + acquirer_employees_in_state
    do "$PKG/_rules/dedup_key.do" select "target_crd acquirer_crd target_acquired_year" "combined_employees" _N

* Report the pair construction diagnostics
    count
    local n_unique_pairs = r(N)
    di "=========================================="
    di "PAIR CONSTRUCTION DIAGNOSTICS (TIME WINDOW)"
    di "=========================================="
    di "Target-state-year combinations: " `n_target_state_year'
    di "Rows after joinby and ±1 year filter: " `n_after_joinby'
    di "Unique (target, acquirer) pairs: " `n_unique_pairs'
    di "Average matches per target-state: " `n_after_joinby'/`n_target_state_year'

* Use the target's acquired year as the reference year for the pair
    ren state_match state_shared
    drop combined_employees year_diff
    gen acquired_year = target_acquired_year
    sort target_crd acquirer_crd acquired_year
    save data/output/all_possible_pairs_timewin, replace

* Assign the shared state to both firms (both have employees there by construction)
    use data/output/all_possible_pairs_timewin, clear
    gen state_target = state_shared
    gen state_acquirer = state_shared

* Merge with the real pairs to flag actual mergers (real_match = 100)
    merge m:1 target_crd acquirer_crd acquired_year using data/output/merger_data_small_timewin, ///
          keepusing(target_crd acquirer_crd acquired_year)
    drop if _m ==2
    gen real_match = (_merge == 3)
    replace real_match = real_match * 100
    drop _merge state_shared
    duplicates drop

* Report the choice set diagnostics
    di "=========================================="
    di "CHOICE SET DIAGNOSTICS (TIME WINDOW)"
    di "=========================================="
    count
    di "Total possible pairs created: " r(N)
    count if real_match == 100
    di "Number of real mergers: " r(N)
    egen pairs_per_target = count(acquirer_crd), by(target_crd)
    sum pairs_per_target, detail
    di "Average choice set size per target: " r(mean)
    egen pairs_per_acquirer = count(target_crd), by(acquirer_crd)
    sum pairs_per_acquirer, detail
    di "Average times each acquirer appears: " r(mean)

* Drop target-years with no counterfactual pair
    do "$PKG/_rules/thresholds.do" candidates "target_crd acquired_year" real_match

* Check that the matching states are identical
    gen same_state_match = (state_target == state_acquirer)
    assert same_state_match == 1
    drop pairs_per_target pairs_per_acquirer same_state_match
    save data/output/merger_pairs_timewin, replace

* Clean up temporary files
    erase data/output/registrationhistory_temp.dta
    erase data/output/brokeryear_temp.dta
    erase data/output/brokeryearemployment_temp.dta
    erase data/output/targets_timewin_temp.dta
    erase data/output/acquirers_timewin_temp.dta
    erase data/output/all_possible_pairs_timewin.dta
    erase data/output/merger_data_small_timewin.dta


********************************************************************************
* Step 4: misconduct of targets and acquirers
********************************************************************************

* Add target misconduct and employees to the pairs (prefix t)
    use data/output/firm_adv_controls, clear
    ren organizationcrd crd_number
    do "$PKG/_rules/employee_timing.do" pair target_crd
    gen acquired_year = fiscal_year + 1
    merge 1:m target_crd acquired_year using data/output/merger_pairs_timewin
    keep if _m == 3
    drop _m
    foreach x in egan_intensity_flow egan_intensity_three ///
                 any_intensity_flow any_intensity_three any_disclosureall egan_disclosureall employees {
        ren `x' t`x'
    }
    save data/output/temp_four_timewin, replace

* Add acquirer misconduct and employees to the pairs (prefix a)
    use data/output/firm_adv_controls, clear
    ren organizationcrd crd_number
    do "$PKG/_rules/employee_timing.do" pair acquirer_crd
    gen acquired_year = fiscal_year + 1
    merge 1:m acquirer_crd acquired_year using data/output/temp_four_timewin
    keep if _m == 3
    drop _m
    foreach x in egan_intensity_flow egan_intensity_three ///
                 any_intensity_flow any_intensity_three employees ///
                 any_disclosureall egan_disclosureall {
        ren `x' a`x'
    }
    save data/output/matching_frame_tw, replace

* Combine misconduct by taking the absolute difference in misconduct per employee
    use data/output/matching_frame_tw, clear
    drop if aemployees ==. | temployees ==.
    gen combined_m = abs((aany_intensity_three/aemployees) - (tany_intensity_three/temployees))
    gen combined_two_m = abs((aegan_intensity_three/aemployees) - (tegan_intensity_three/temployees))

* Misconduct shares (percent) and whether each is positive
    gen acquirer_misc_a = (aany_intensity_three/aemployees)*100
    gen target_misc_a = (tany_intensity_three/temployees)*100
    gen acquirer_misc_e = (aegan_intensity_three/aemployees)*100
    gen target_misc_e = (tegan_intensity_three/temployees)*100
    gen misc_cut_aa =  (acquirer_misc_a >0)
    gen misc_cut_ta =  (target_misc_a > 0)
    gen misc_cut_ae =  (acquirer_misc_e >0)
    gen misc_cut_te =  (target_misc_e >0)

* Flag pairs with the same disclosure status (both or neither), for all misconduct
* (dummy_one) and EMS misconduct (dummy_two); Table V uses both
    gen dummy_one = ((misc_cut_aa ==1 & misc_cut_ta==1) | (misc_cut_aa ==0 & misc_cut_ta==0))
    gen dummy_two = ((misc_cut_ae ==1 & misc_cut_te ==1) |(misc_cut_ae ==0 & misc_cut_te==0))
    save data/output/matching_frame_tw, replace


********************************************************************************
* Target characteristics
********************************************************************************

* Keep the target's Form ADV characteristics
    use data/output/firm_adv_controls, clear
    gen acquired_year = fiscal_year + 1
    ren organizationcrd target_crd
    keep target_crd acquired_year  number_clients ///
         retail_clients dollar_aum adviser_age    ///
         financial_planning port_mgmt_indv_sb ///
         port_mgmt_inv_c port_mgmt_bus_insc pension_cs ///
         selection_advisers publication_periodicals ratings_pricing market_timing other port_mgmt_pif ///
         interestintransacton conflictedadvice softdollars soliciting_clients compensation_hourly ///
         compensation_fixed compensation_commission compensation_performance ///
         past_criminal_felony past_criminal_misdemeanor pastregulatory pastcivil

* Suffix them _t
    foreach x in number_clients ///
                 retail_clients dollar_aum adviser_age ///
                 financial_planning port_mgmt_indv_sb ///
                 port_mgmt_inv_c port_mgmt_bus_insc pension_cs ///
                 selection_advisers publication_periodicals ratings_pricing market_timing other port_mgmt_pif ///
                 interestintransacton conflictedadvice softdollars soliciting_clients compensation_hourly ///
                 compensation_fixed compensation_commission compensation_performance ///
                 past_criminal_felony past_criminal_misdemeanor pastregulatory pastcivil {
        ren `x' `x'_t
    }

* Merge them onto the pairs
    merge 1:m target_crd acquired_year using data/output/matching_frame_tw
    keep if _m ==3
    drop _m
    save data/output/temp_six_timewin, replace


********************************************************************************
* Acquirer characteristics
********************************************************************************

* Keep the acquirer's Form ADV characteristics
    use data/output/firm_adv_controls, clear
    gen acquired_year = fiscal_year + 1
    ren organizationcrd acquirer_crd
    keep acquirer_crd acquired_year number_clients ///
         retail_clients dollar_aum adviser_age   ///
         financial_planning port_mgmt_indv_sb ///
         port_mgmt_inv_c port_mgmt_bus_insc pension_cs ///
         selection_advisers publication_periodicals ratings_pricing market_timing other  port_mgmt_pif ///
         interestintransacton conflictedadvice softdollars soliciting_clients compensation_hourly ///
         compensation_fixed compensation_commission compensation_performance  ///
         past_criminal_felony past_criminal_misdemeanor pastregulatory pastcivil

* Suffix them _a
    foreach x in number_clients ///
                 retail_clients dollar_aum adviser_age   ///
                 financial_planning port_mgmt_indv_sb ///
                 port_mgmt_inv_c port_mgmt_bus_insc pension_cs ///
                 selection_advisers publication_periodicals ratings_pricing market_timing other port_mgmt_pif ///
                 interestintransacton conflictedadvice softdollars soliciting_clients compensation_hourly ///
                 compensation_fixed compensation_commission compensation_performance ///
                 past_criminal_felony past_criminal_misdemeanor pastregulatory pastcivil {
        ren `x' `x'_a
    }

* Merge them onto the pairs; the state variables are already in the data
    merge 1:m acquirer_crd acquired_year using data/output/temp_six_timewin
    keep if _m ==3
    drop _m
    ren state_target state_t
    ren state_acquirer state_a

* Check state variation: every pair has employees in the same state
    di "=========================================="
    di "STATE VARIATION DIAGNOSTICS (TIME WINDOW)"
    di "=========================================="
    gen same_state_check = (state_a == state_t)
    tab same_state_check
    di "Variation in same_state: "
    sum same_state_check
    di "% of pairs where employees in same state: " r(mean)*100
    assert same_state_check == 1
    drop same_state_check
    save data/output/matching_frame_timewin, replace


********************************************************************************
* Table VI regressions
********************************************************************************

* Load the pairs, restrict the acquisition years and drop the raw industry controls
    use data/output/matching_frame_timewin, clear
    do "$PKG/_helpers/restrict_acquired_year.do"
    cap drop retail_clients financial_planning port_mgmt_indv_sb port_mgmt_inv_c port_mgmt_bus_insc ///
             pension_cs selection_advisers publication_periodicals ratings_pricing ///
             market_timing other broker_dealer_dummy

* Flag pairs where both firms are in the bottom or top AUM quintile of the year
    bys acquired_year:  egen large_target = xtile(dollar_aum_t), nquant(5)
    bys acquired_year:  egen large_acquirer = xtile(dollar_aum_a), nquant(5)
    gen match1 = (large_target == 1 & large_acquirer ==1)
    gen match5 = (large_target == 5 & large_acquirer ==5)

* Similarity in state, retail clients, and absolute log differences in size and age
    gen same_state = (state_a == state_t)
    gen retail_clients = (retail_clients_a == retail_clients_t)
    gen aum_ratio = abs(ln(dollar_aum_a) - ln(dollar_aum_t))
    gen age_ratio = abs(ln(adviser_age_a) - ln(adviser_age_t))
    gen employee_ratio = abs(ln(aemployees) - ln(temployees))

* Same past criminal, regulatory and civil events
    gen past_criminal_felony = (past_criminal_felony_a == past_criminal_felony_t)
    gen past_criminal_misdemeanor = (past_criminal_misdemeanor_a == past_criminal_misdemeanor_t)
    gen pastregulatory = (pastregulatory_a == pastregulatory_t)
    gen pastcivil = (pastcivil_a == pastcivil_t)

* Same advisory services
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

* Same compensation arrangements
    gen compensationh = ( compensation_hourly_a == compensation_hourly_t)
    gen compensationf = ( compensation_fixed_a == compensation_fixed_t)
    gen compensation_commission = ( compensation_commission_a == compensation_commission_t)
    gen compensation_performance = ( compensation_performance_a == compensation_performance_t )

* Standardize the differences, label the regressors and build the acquirer cluster variable
    do "$PKG/_rules/winsorize_last.do" timewin_labels ""

* Outcome, fixed effects, clustering and the control sets for the eight columns. The sample rule
* absorbs year effects; the regressions absorb target-by-year effects, so the rank is compared
* only across the candidates of the same target
    local fe1  acquired_year
    local fe_pair  target_crd#acquired_year
    local clustervar clustervar
    local indepvar1  real_match
    local controls  relrank_a
    local controls1  relrank_a retail_clients aum_ratio_z age_ratio_z employee_ratio_z same_state
    local controls2  relrank_a retail_clients aum_ratio_z age_ratio_z employee_ratio_z same_state match1 match5
    local controls3  relrank_a retail_clients aum_ratio_z age_ratio_z employee_ratio_z same_state match1 match5 ///
                     past_criminal_felony past_criminal_misdemeanor pastregulatory pastcivil
    local controls4  relrank_e
    local controls5  relrank_e retail_clients  aum_ratio_z age_ratio_z employee_ratio_z same_state
    local controls6  relrank_e retail_clients  aum_ratio_z age_ratio_z employee_ratio_z same_state match1 match5
    local controls7  relrank_e retail_clients  aum_ratio_z age_ratio_z employee_ratio_z same_state match1 match5 ///
                     past_criminal_felony past_criminal_misdemeanor pastregulatory pastcivil

* Industry fixed effects: same advisory services
    local industry  financial_planning port_mgmt_indv_sb ///
                    port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other

* Restrict to the estimation sample, winsorize and restandardize the differences
    do "$PKG/_rules/winsorize_last.do" pair_final "aum_ratio age_ratio employee_ratio" "`industry'" "`fe1'" "`clustervar'"

* Misconduct Distance Rank: the rank of the asinh distance in misconduct per employee between
* the candidate acquirer and the target within the target's candidate set, scaled from 0
* (closest) to 1 (farthest); tied candidates share the average rank. Computed over the
* estimation sample
    foreach m in a e {
        gen adist_`m' = abs(asinh(acquirer_misc_`m') - asinh(target_misc_`m'))
        bys target_crd acquired_year: egen double rk_`m' = rank(adist_`m')
        bys target_crd acquired_year: gen double nset_`m' = _N
        gen double relrank_`m' = (rk_`m' - 1) / (nset_`m' - 1)
    }
    la var relrank_a "Misconduct Distance Rank (All)"
    la var relrank_e "Misconduct Distance Rank (EMS)"

* Save the estimation sample for Table A.5 and the numbers the text quotes
    save data/output/matching_sample_timewin, replace

* Estimate the eight columns
    eststo clear
    eststo:  reghdfe `indepvar1' `controls' if sample, absorb(`fe_pair' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls1' if sample, absorb(`fe_pair' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls2' if sample, absorb(`fe_pair' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls3' if sample, absorb(`fe_pair' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls4' if sample, absorb(`fe_pair' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls5' if sample, absorb(`fe_pair' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls6' if sample, absorb(`fe_pair' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls7' if sample, absorb(`fe_pair' `industry') vce(cluster `clustervar')

* Write the table
    esttab _all using "tables/matching_regression_TimeWindow2023.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(relrank_a relrank_e pastregulatory pastcivil past_criminal_misdemeanor ///
           past_criminal_felony) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst
