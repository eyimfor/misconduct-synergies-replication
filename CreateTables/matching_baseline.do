********************************************************************************
* Builds all target-acquirer pairs within each merger year (real and counterfactual
* matches), adds both firms' misconduct and Form ADV characteristics, and estimates
* Table V (matching on misconduct). Also saves matching_frame_full.dta, which
* appendix_industry_controls.do and Figure A.3 use.
********************************************************************************
clear


********************************************************************************
* Pair frame: do targets and acquirers match on misconduct?
********************************************************************************

* Create pairs of all targets and acquirers in the M&A market in the same year
    do "$PKG/_rules/merger_window.do" mergeryear load "data/output/merger_sample"
    do "$PKG/_rules/dedup_key.do" select "target_crd mergeryear" "acquirercrds" _N
    keep acquirercrds mergeryear target_crd
    ren (acquirercrds mergeryear) (acquirer_crd acquired_year)
    duplicates drop
    save data/output/merger_data_small_two25, replace

* Create real and counterfactual merger pairs
    use data/output/merger_data_small_two25, clear
    ren (target_crd) (target_one)
    duplicates drop
    joinby acquired_year using  data/output/merger_data_small_two25
    sort target_one target_crd
    gen real_match = (target_one == target_crd)
    drop target_one
    duplicates drop

* Keep one row per pair and apply the candidate thresholds
    do "$PKG/_rules/dedup_key.do" select "target_crd acquirer_crd" "real_match" _N
    sort target_crd
    do "$PKG/_rules/thresholds.do" candidates "target_crd acquired_year" real_match data/output/merger_pairs

* Import target controls and add disclosures
    use data/output/firm_adv_controls, clear
    ren organizationcrd crd_number
    do "$PKG/_rules/employee_timing.do" pair target_crd
    gen acquired_year = fiscal_year + 1

* Add misconduct to target
    merge 1:m target_crd acquired_year using data/output/merger_pairs
    keep if _m == 3
    drop _m
    foreach x in egan_intensity_flow egan_intensity_three any_intensity_flow any_intensity_three any_disclosureall egan_disclosureall employees  ///
    {
        ren `x' t`x'
    }
    save data/output/temp_four, replace

* Import acquirer controls and add disclosures
    use data/output/firm_adv_controls, clear
    ren organizationcrd crd_number
    do "$PKG/_rules/employee_timing.do" pair acquirer_crd
    gen acquired_year = fiscal_year + 1

* Add misconduct to acquirer
    merge 1:m acquirer_crd acquired_year using data/output/temp_four
    keep if _m == 3
    drop _m
    foreach x in egan_intensity_flow egan_intensity_three any_intensity_flow any_intensity_three employees any_disclosureall egan_disclosureall  ///
    {
        ren `x' a`x'
    }
    save data/output/matching_frame, replace

* Combine misconduct by taking the absolute difference
    use data/output/matching_frame, clear
    drop if aemployees ==. | temployees ==.
    gen combined_m = abs((aany_intensity_three/aemployees) - (tany_intensity_three/temployees))
    gen combined_two_m = abs((aegan_intensity_three/aemployees) - (tegan_intensity_three/temployees))

* Misconduct per employee (percent) for each side
    gen acquirer_misc_a = (aany_intensity_three/aemployees)*100
    gen target_misc_a = (tany_intensity_three/temployees)*100
    gen acquirer_misc_e = (aegan_intensity_three/aemployees)*100
    gen target_misc_e = (tegan_intensity_three/temployees)*100

* Flag pairs where both firms have misconduct
    gen misc_cut_aa =  (acquirer_misc_a >0)
    gen misc_cut_ta =  (target_misc_a > 0)
    gen misc_cut_ae =  (acquirer_misc_e >0)
    gen misc_cut_te =  (target_misc_e >0)
    gen dummy_one = (misc_cut_aa & misc_cut_ta)
    gen dummy_two = (misc_cut_ae & misc_cut_te)
    replace real_match = real_match*100
    save data/output/matching_frame, replace

* Add other target characteristics
    use data/output/firm_adv_controls, clear
    gen acquired_year = fiscal_year + 1
    ren organizationcrd target_crd
    keep target_crd acquired_year  number_clients state  ///
         retail_clients dollar_aum adviser_age    ///
         financial_planning port_mgmt_indv_sb ///
         port_mgmt_inv_c port_mgmt_bus_insc pension_cs ///
         selection_advisers publication_periodicals ratings_pricing market_timing other port_mgmt_pif ///
         interestintransacton conflictedadvice softdollars soliciting_clients compensation_hourly ///
         compensation_fixed compensation_commission compensation_performance ///
         past_criminal_felony past_criminal_misdemeanor pastregulatory pastcivil

* Suffix target characteristics with _t
    foreach x in number_clients state  ///
                 retail_clients dollar_aum adviser_age ///
                 financial_planning port_mgmt_indv_sb ///
                 port_mgmt_inv_c port_mgmt_bus_insc pension_cs ///
                 selection_advisers publication_periodicals ratings_pricing market_timing other port_mgmt_pif ///
                 interestintransacton conflictedadvice softdollars soliciting_clients compensation_hourly ///
                 compensation_fixed compensation_commission compensation_performance ///
                 past_criminal_felony past_criminal_misdemeanor pastregulatory pastcivil   ///
    {
        ren `x' `x'_t
    }

* Merge target characteristics into the pair frame
    merge 1:m target_crd acquired_year using data/output/matching_frame
    keep if _m ==3
    drop _m
    save data/output/temp_six, replace

* Add other acquirer characteristics
    use data/output/firm_adv_controls, clear
    gen acquired_year = fiscal_year + 1
    ren organizationcrd acquirer_crd
    keep acquirer_crd acquired_year number_clients state  ///
         retail_clients dollar_aum adviser_age   ///
         financial_planning port_mgmt_indv_sb ///
         port_mgmt_inv_c port_mgmt_bus_insc pension_cs ///
         selection_advisers publication_periodicals ratings_pricing market_timing other  port_mgmt_pif ///
         interestintransacton conflictedadvice softdollars soliciting_clients compensation_hourly ///
         compensation_fixed compensation_commission compensation_performance  ///
         past_criminal_felony past_criminal_misdemeanor pastregulatory pastcivil

* Suffix acquirer characteristics with _a
    foreach x in number_clients state  ///
                 retail_clients dollar_aum adviser_age   ///
                 financial_planning port_mgmt_indv_sb ///
                 port_mgmt_inv_c port_mgmt_bus_insc pension_cs ///
                 selection_advisers publication_periodicals ratings_pricing market_timing other port_mgmt_pif ///
                 interestintransacton conflictedadvice softdollars soliciting_clients compensation_hourly ///
                 compensation_fixed compensation_commission compensation_performance ///
                 past_criminal_felony past_criminal_misdemeanor pastregulatory pastcivil  ///
    {
        ren `x' `x'_a
    }

* Add acquirer to target statistics
    merge 1:m acquirer_crd acquired_year using data/output/temp_six
    keep if _m ==3
    drop _m
    save data/output/matching_frame_full, replace


********************************************************************************
* Pair frame with controls and Table V regressions
********************************************************************************

* Load the pair frame and apply the merger-year restriction
    use data/output/matching_frame_full, clear
    do "$PKG/_helpers/restrict_acquired_year.do"
    cap drop retail_clients financial_planning port_mgmt_indv_sb port_mgmt_inv_c port_mgmt_bus_insc ///
             pension_cs selection_advisers publication_periodicals ratings_pricing ///
             market_timing other broker_dealer_dummy

* Define dummy for when target and acquirer are both large or small
    bys acquired_year:  egen large_target = xtile(dollar_aum_t), nquant(5)
    bys acquired_year:  egen large_acquirer = xtile(dollar_aum_a), nquant(5)
    gen match1 = (large_target == 1 & large_acquirer ==1)
    gen match5 = (large_target == 5 & large_acquirer ==5)

* Define other controls
    gen same_state = (state_a == state_t)
    gen retail_clients = (retail_clients_a == retail_clients_t)
    gen aum_ratio = abs(ln(dollar_aum_a) - ln(dollar_aum_t))
    gen age_ratio = abs(ln(adviser_age_a) - ln(adviser_age_t))
    gen employee_ratio = abs(ln(aemployees) - ln(temployees))

* Other disclosures (firm-level)
    gen past_criminal_felony = (past_criminal_felony_a == past_criminal_felony_t)
    gen past_criminal_misdemeanor = (past_criminal_misdemeanor_a == past_criminal_misdemeanor_t)
    gen pastregulatory = (pastregulatory_a == pastregulatory_t)
    gen pastcivil = (pastcivil_a == pastcivil_t)

* Flag whether target and acquirer match on each advisory service
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

* How are advisers compensated
    gen compensationh = ( compensation_hourly_a == compensation_hourly_t)
    gen compensationf = ( compensation_fixed_a == compensation_fixed_t)
    gen compensation_commission = ( compensation_commission_a == compensation_commission_t)
    gen compensation_performance = ( compensation_performance_a == compensation_performance_t )

* Standardize and label the regression variables
    do "$PKG/_rules/winsorize_last.do" pair_labels_tex ""
    la var dummy_two "Acq \& Tar Employees with misconduct (EMS)"
    la var combined_m_z "$|\text{Misconduct} \text{(Acq} - \text{Tar (All))}|$"
    la var combined_two_m_z "$|\text{Misconduct} \text{(Acq} - \text{Tar (Egan)}|$"
    la var aum_ratio_z "$|\text{Ln(AUM Acq)}- \text{Ln(AUM Tar)}|$"
    la var age_ratio_z "$|\text{Ln(Age Acq)}- \text{Ln(Age Tar)}|$"
    la var employee_ratio_z "$|\text{Ln(Emp Acq)} - \text{Ln(Emp Tar)}|$"
    la var retail_clients "Retail clients"
    la var past_criminal_felony "Criminal Felony Both"
    la var past_criminal_misdemeanor "Criminal Misdemeanor Both"
    la var pastregulatory "Regulatory Events Both"
    la var pastcivil "Civil Events Both"
    la var same_state "Same state"
    la var match1 "Target \& Acquirer Small"
    la var match5 "Target \& Acquirer Large"

* Define the cluster variable
    do "$PKG/_rules/cluster.do"

* Does misconduct affect the probability of a merger? Outcome, fixed effects and cluster
    local fe1  acquired_year
    local clustervar clustervar
    local indepvar1  real_match

* Control sets for the all-misconduct columns
    local controls  dummy_one
    local controls1  dummy_one    ///
          retail_clients aum_ratio_z age_ratio_z employee_ratio_z same_state
    local controls2  dummy_one    ///
          retail_clients aum_ratio_z age_ratio_z employee_ratio_z same_state match1 match5
    local controls3  dummy_one    ///
          retail_clients aum_ratio_z age_ratio_z employee_ratio_z same_state match1 match5 ///
          past_criminal_felony past_criminal_misdemeanor pastregulatory pastcivil

* Control sets for the EMS misconduct columns
    local controls4  dummy_two
    local controls5  dummy_two ///
          retail_clients  aum_ratio_z age_ratio_z employee_ratio_z same_state
    local controls6  dummy_two ///
          retail_clients  aum_ratio_z age_ratio_z employee_ratio_z same_state match1 match5
    local controls7  dummy_two ///
          retail_clients  aum_ratio_z age_ratio_z employee_ratio_z same_state match1 match5 ///
          past_criminal_felony past_criminal_misdemeanor pastregulatory pastcivil

* Industry fixed effects; keep the regression sample, then winsorize and standardize
    local industry  financial_planning port_mgmt_indv_sb ///
          port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other
    do "$PKG/_rules/winsorize_last.do" pair_final "aum_ratio age_ratio employee_ratio" "`industry'" "`fe1'" "`clustervar'"

* Estimate Table V
    eststo clear
    eststo:  reghdfe `indepvar1' `controls' if sample, absorb(`fe1' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls1' if sample, absorb(`fe1' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls2' if sample, absorb(`fe1' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls3' if sample, absorb(`fe1' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls4' if sample, absorb(`fe1' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls5' if sample, absorb(`fe1' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls6' if sample, absorb(`fe1' `industry') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar1' `controls7' if sample, absorb(`fe1' `industry') vce(cluster `clustervar')

* Export the table
    esttab _all using "tables/matching_regression_raw.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(dummy_one dummy_two pastregulatory pastcivil past_criminal_misdemeanor ///
           past_criminal_felony) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst
