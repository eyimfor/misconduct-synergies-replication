********************************************************************************
* Winsorizes misconduct measures and absolute log differences once, at the 1% and 99% levels, pooled
* over the final estimation sample of the exhibit being produced, then standardizes them.
* Used by Tables II-IX, XII (Panels A and B), A.2, A.3, A.4, A.6, A.7 and Figures 4, 6 and A.3.
* Exceptions: Table II winsorizes without standardizing; the Table XII logs are not winsorized.
********************************************************************************
* all_regression and adviser_event_panel are saved unwinsorized.
* Usage: do winsorize_last.do <operation> "<winsor variable list>" ["<industry>" "<year FE>" "<cluster>"]
* All caller values are passed as arguments; recursive calls have their own locals.
args operation variables p1 p2 p3

* cut: winsorize the listed variables at the 1st and 99th percentiles, in place
    if "`operation'" == "cut" {
        winsor2 `variables', cut(1,99) replace
        exit
    }

* standardize: write std(x) to x<p1>, or to the one destination named in p2 (a source-variable alias)
    if "`operation'" == "standardize" {
        tempvar standardized
        foreach x of local variables {
            local destination "`x'`p1'"
            if "`p2'" != "" local destination "`p2'"
            egen double `standardized' = std(`x')

            * Create the destination with the source's label, or overwrite it if it exists
            capture confirm variable `destination'
            if _rc {
                gen `destination' = `standardized'
                _crcslbl `destination' `x'
            }
            else {
                replace `destination' = `standardized'
            }
            drop `standardized'
        }
        exit
    }

* defer_logs: define the logs only; winsorizing is left to the final-sample call
    if "`operation'" == "defer_logs" {
        gen ln_aum = ln(dollar_aum + 1)
        gen ln_clients = ln(number_clients)
        exit
    }

* target_final: drop rows with obs == 1, keep the target regression sample, winsorize and standardize
    if "`operation'" == "target_final" {
        drop if obs == 1
        drop obs
        quietly reghdfe target fraction_bad_three fraction_bad_four retail_clients ln_aum ln_age ln_employees, absorb(financial_planning port_mgmt_indv_sb port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other fiscal_year) vce(cluster crd)
        keep if e(sample)
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        do "$PKG/_rules/winsorize_last.do" standardize "number_clients adviser_age fraction_bad_three fraction_bad_four ln_aum ln_clients ln_age ln_employees" "_z"
        exit
    }

* target_final_scaled: scale target to percent, keep its regression sample, winsorize and standardize
    if "`operation'" == "target_final_scaled" {
        replace target = target*100
        quietly reghdfe target fraction_bad_three fraction_bad_four retail_clients ln_aum ln_age ln_employees, absorb(financial_planning port_mgmt_indv_sb port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other fiscal_year) vce(cluster crd)
        keep if e(sample)
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        do "$PKG/_rules/winsorize_last.do" standardize "number_clients adviser_age fraction_bad_three fraction_bad_four ln_aum ln_clients ln_age ln_employees" "_z"
        exit
    }

* acquirer_final: scale acquirer to percent, keep its regression sample, winsorize and standardize
    if "`operation'" == "acquirer_final" {
        replace acquirer = acquirer*100
        quietly reghdfe acquirer fraction_bad_three fraction_bad_four retail_clients ln_aum ln_age ln_employees, absorb(financial_planning port_mgmt_indv_sb port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other fiscal_year) vce(cluster crd)
        keep if e(sample)
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        do "$PKG/_rules/winsorize_last.do" standardize "number_clients adviser_age fraction_bad_three fraction_bad_four ln_aum ln_clients ln_age ln_employees" "_z"
        exit
    }

* appendix_target_final: as target_final, with the service dummies as controls and fiscal-year FE only
    if "`operation'" == "appendix_target_final" {
        drop if obs == 1
        drop obs
        quietly reghdfe target fraction_bad_three fraction_bad_four retail_clients ln_aum ln_age ln_employees financial_planning port_mgmt_indv_sb port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other, absorb(fiscal_year) vce(cluster crd)
        keep if e(sample)
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        do "$PKG/_rules/winsorize_last.do" standardize "number_clients adviser_age fraction_bad_three fraction_bad_four ln_aum ln_clients ln_age ln_employees" "_z"
        exit
    }

* appendix_acquirer_final: as acquirer_final, with the service dummies as controls and fiscal-year FE only
    if "`operation'" == "appendix_acquirer_final" {
        replace acquirer = acquirer*100
        quietly reghdfe acquirer fraction_bad_three fraction_bad_four retail_clients ln_aum ln_age ln_employees financial_planning port_mgmt_indv_sb port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other, absorb(fiscal_year) vce(cluster crd)
        keep if e(sample)
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        do "$PKG/_rules/winsorize_last.do" standardize "number_clients adviser_age fraction_bad_three fraction_bad_four ln_aum ln_clients ln_age ln_employees" "_z"
        exit
    }

* table2_final: drop rows missing any listed variable, then winsorize without standardizing
    if "`operation'" == "table2_final" {
        foreach x in crd employees fraction_bad_ever fraction_bad_e_ever fraction_bad_a fraction_bad_e fraction_bad_a_flow fraction_bad_e_flow dollar_aum aum_growth_mean number_clients client_growth_mean target {
            drop if missing(`x')
        }
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        exit
    }

* aum_per_employee_final: keep the log AUM-per-employee regression sample, winsorize and standardize
    if "`operation'" == "aum_per_employee_final" {
        quietly reghdfe ln_aum_emp fraction_bad_three fraction_bad_four retail_clients ln_age ln_employees, absorb(year_aum crd_number) vce(cluster crd_number)
        keep if e(sample)
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        do "$PKG/_rules/winsorize_last.do" standardize "number_clients adviser_age fraction_bad_three fraction_bad_four ln_clients ln_age ln_employees" "_z"
        eststo clear
        exit
    }

* firm_closure_final: keep the firm-closure regression sample, winsorize and standardize
    if "`operation'" == "firm_closure_final" {
        quietly reghdfe failed fraction_bad_three fraction_bad_four retail_clients ln_age ln_employees, absorb(year_aum financial_planning port_mgmt_indv_sb port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other) vce(cluster organizationcrd)
        keep if e(sample)
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        do "$PKG/_rules/winsorize_last.do" standardize "number_clients adviser_age fraction_bad_three fraction_bad_four ln_clients ln_age ln_employees" "_z"
        eststo clear
        exit
    }

* pair_labels_plain: standardize the pair variables and label dummy_one in plain text
    if "`operation'" == "pair_labels_plain" {
        do "$PKG/_rules/winsorize_last.do" standardize "aum_ratio combined_m combined_two_m  age_ratio employee_ratio" "_z"
        la var dummy_one "Acq & Tar Employees with misconduct (All)"
        exit
    }

* pair_labels_tex: standardize the pair variables and label dummy_one for LaTeX
    if "`operation'" == "pair_labels_tex" {
        do "$PKG/_rules/winsorize_last.do" standardize "aum_ratio combined_m combined_two_m  age_ratio employee_ratio" "_z"
        la var dummy_one "Acq \& Tar Employees with misconduct (All)"
        exit
    }

* pair_final: keep the pair regression sample (industry and year FE absorbed), winsorize and standardize
    if "`operation'" == "pair_final" {
        local industry "`p1'"
        local fe1 "`p2'"
        local clustervar "`p3'"
        quietly reghdfe real_match dummy_one dummy_two retail_clients aum_ratio age_ratio employee_ratio same_state match1 match5, absorb(`industry' `fe1') vce(cluster `clustervar')
        gen byte sample = e(sample)
        keep if sample
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        do "$PKG/_rules/winsorize_last.do" standardize "aum_ratio combined_m combined_two_m age_ratio employee_ratio" "_z"
        exit
    }

* timewin_labels: standardize the pair variables, label them for LaTeX, build the cluster id
    if "`operation'" == "timewin_labels" {
        do "$PKG/_rules/winsorize_last.do" standardize "aum_ratio combined_m combined_two_m  age_ratio employee_ratio" "_z"

        * LaTeX variable labels
        la var dummy_one "Acq \& Tar Employees with misconduct (All)"
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

        * Cluster on the acquirer
        egen clustervar = group(acquirer_crd)
        exit
    }

* a4_pair_final: as pair_final, with the industry variables as regressors and only year FE absorbed
    if "`operation'" == "a4_pair_final" {
        local industry "`p1'"
        local fe1 "`p2'"
        local clustervar "`p3'"
        quietly reghdfe real_match dummy_one dummy_two retail_clients aum_ratio age_ratio employee_ratio same_state match1 match5 `industry', absorb(`fe1') vce(cluster `clustervar')
        gen byte sample = e(sample)
        keep if sample
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        do "$PKG/_rules/winsorize_last.do" standardize "aum_ratio combined_m combined_two_m age_ratio employee_ratio" "_z"
        exit
    }

* stats_tables_final: save the unwinsorized panel, then winsorized subsamples for the stats tables
    if "`operation'" == "stats_tables_final" {
        save data/output/adviser_event_panel, replace

        * Real mergers (treated == 1), complete cases
        preserve
        keep if treated == 1
        foreach x in id employees fraction_bad_a_flow fraction_bad_e_flow all_intensity_flow1 egan_intensity_flow1 dollar_aumc combined_aumg number_clientsc combined_clg post {
            drop if missing(`x')
        }
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        save data/output/misconductdroptest_table7, replace
        restore

        * Pseudo mergers (treated == 0), complete cases
        preserve
        keep if treated == 0
        foreach x in id employees fraction_bad_a_flow fraction_bad_e_flow all_intensity_flow1 egan_intensity_flow1 dollar_aumc combined_aumg number_clientsc combined_clg post {
            drop if missing(`x')
        }
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        save data/output/misconductdroptest_table8, replace
        restore

        * Event-study sample for the figure
        preserve
        drop if missing(event_time, treated, fraction_bad_a_flow)
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        save data/output/misconductdroptest_figure4, replace
        restore
        exit
    }

* ix_final: keep the post-merger misconduct regression sample, winsorize, standardize the controls
    if "`operation'" == "ix_final" {
        quietly reghdfe fraction_bad_a_flow interaction treated post both_retailc ln_aum_std ln_age_z ln_employees_std fraction_bad_e_flow, absorb(year_aum) vce(cluster cohort)
        keep if e(sample)
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        do "$PKG/_rules/winsorize_last.do" standardize "ln_employees" "_std"
        do "$PKG/_rules/winsorize_last.do" standardize "ln_age" "_z"
        do "$PKG/_rules/winsorize_last.do" standardize "dollar_aum" "" "ln_aum_std"
        eststo clear
        exit
    }

* a6_final: as ix_final, with the interaction with pastacquirer added
    if "`operation'" == "a6_final" {
        gen interactionthree = interaction*pastacquirer
        quietly reghdfe fraction_bad_a_flow interactionthree interaction treated post pastacquirer both_retailc ln_aum_std ln_age_z ln_employees_std fraction_bad_e_flow, absorb(year_aum) vce(cluster cohort)
        keep if e(sample)
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        do "$PKG/_rules/winsorize_last.do" standardize "ln_employees" "_std"
        do "$PKG/_rules/winsorize_last.do" standardize "ln_age" "_z"
        do "$PKG/_rules/winsorize_last.do" standardize "dollar_aum" "" "ln_aum_std"
        exit
    }

* figure6_final: keep the event-study regression sample and winsorize
    if "`operation'" == "figure6_final" {
        quietly reghdfe any_misconduct pre_3 pre_2 pre_1 current post_1 post_2 post_3 treated, absorb(id##year) vce(cluster id)
        keep if e(sample)
        do "$PKG/_rules/winsorize_last.do" cut "`variables'"
        eststo clear
        exit
    }

* Reject an unknown operation
    display as error "Unknown winsorize_last operation: `operation'"
    exit 198
