********************************************************************************
* Figure 6: builds fig6_adviser_panel, the adviser-year panel for the
* no-separation counterfactual. It tracks only advisers employed at the target or
* acquirer before the merger (post-merger hires are excluded), which separates the
* effect of separations from changes in composition due to hiring.
********************************************************************************
clear


********************************************************************************
* Step 1: Identify real mergers (targets and acquirers)
********************************************************************************

* Import merger data and keep only real transactions
    do "$PKG/_rules/merger_window.do" acquired_year load "data/output/merger_pairs_long"
    * Real mergers only: in merger_pairs_long, count 0 is the target and 3 the acquirer
    keep if count ==0 | count == 3 // real targets and acquirers

* Flag targets and save the real merger list
    gen target = (count == 0)
    do "$PKG/_rules/merge_semantics.do" combined_firm_cohort
    * One row per merger and firm: merger id, firm CRD, acquisition year, target indicator
    save data/output/mergerreal_puresep, replace


********************************************************************************
* Step 2: Create cross-section of brokers who worked at target/acquirer firms
********************************************************************************

* Join the real mergers with employment data to find all brokers at these firms
    use data/output/mergerreal_puresep, clear
    ren crd crd_number
    joinby crd_number using data/output/adviser_firm_year

* Record the year each broker started at the target/acquirer firm
    bys b_crd_number crd_number: egen min_year = min(year)

* Keep one row per broker-firm pair with its start year
    keep id b_crd_number crd_number min_year target
    duplicates drop
    save data/output/counterfactual_employeesreal_puresep, replace


********************************************************************************
* Step 3: Create panel of brokers around merger time
********************************************************************************

* Merge back with merger data to get acquired_year
    use data/output/counterfactual_employeesreal_puresep, clear
    ren crd_number crd
    do "$PKG/_rules/event_panel.do" join "id crd" "data/output/mergerreal_puresep"
    duplicates drop

* Track each broker from merger-7 years to merger+7 years
    expand 15, gen(year)
    do "$PKG/_rules/event_panel.do" year "b_crd_number crd id" 8

* Apply the last-year data restriction and keep years from the broker's start onward
    do "$PKG/_helpers/restrict_last_year.do"
    keep if year >= min_year

* Save the cohort panel
    * min_year is kept for the Step 6 filter: it records whether the adviser was hired
    * before the merger year
    keep id b_crd_number crd year min_year
    duplicates drop
    ren crd crd_number
    save data/output/fig6_cohort_employees, replace


********************************************************************************
* Step 4: Add separation indicator and employer information
********************************************************************************

* Shift year forward by 1 and attach the next year's employer
    use data/output/fig6_cohort_employees, clear
    replace year = year+1
    ren crd_number crd_number_prev
    * Separation: the adviser's employer in year t+1 differs from the employer in year t
    joinby b_crd_number year using data/output/adviser_firm_year, unmatched(master)
    drop _m

* Separation = 1 if current firm differs from previous firm
    gen separation = (crd_number != crd_number_prev)
    sort b_crd_number year
    keep id b_crd_number crd_number_prev year separation min_year

* Shift year back to original
    replace year = year - 1
    duplicates drop
    ren crd_number_prev crd

* If broker picked up a new registration, that is not a separation
    do "$PKG/_rules/dedup_key.do" select "id b_crd_number crd year" "separation" 1
    save data/output/employment_counterfactualreal_puresep, replace


********************************************************************************
* Step 5: Add misconduct data
********************************************************************************

* Attach the employment panel to the adviser-year disclosures
    use data/output/rr_disclosures_panel, clear
    * Merge adviser-year disclosures with the employment panel
    * _m==1: adviser-years in the disclosure panel with no row in this employment panel (drop)
    * _m==2: adviser-years in this panel with no disclosure record that year (keep, set to 0)
    merge 1:m b_crd_number year using data/output/employment_counterfactualreal_puresep
    drop if _m ==1
    drop _m

* Replace missing disclosures with zero
    foreach x in settlement_amountd cumulative_disclosures ///
                 cumulative_disclosures_egan egan_intensity any_intensity any_intensity_sum egan_intensity_sum {
        replace `x' = 0 if `x' == .
    }
    save data/output/employment_counterfactual_disclosuresreal_puresep, replace


********************************************************************************
* Step 6: Prepare regression data and apply the pure separation filter
********************************************************************************

* Attach acquired_year to each broker-firm pair
    use data/output/counterfactual_employeesreal_puresep, clear
    ren crd_number crd
    merge m:1 id crd using data/output/mergerreal_puresep
    keep if _m ==3
    drop _m
    * min_year and acquired_year are both needed for the Step 6 filter
    keep id crd target b_crd_number acquired_year min_year
    duplicates drop

* Attach the adviser-year employment and disclosure panel
    merge 1:m id crd b_crd_number using data/output/employment_counterfactual_disclosuresreal_puresep
    keep if _m ==3
    drop _m

* Calculate event time relative to merger and keep observations in the merger window
    gen event_time = year - acquired_year
    * event_time = year - acquired_year
    do "$PKG/_helpers/restrict_event_time.do"

* Pure separation filter: exclude post-merger hires
    * Keep advisers who started at the firm before the merger year (min_year < acquired_year);
    * advisers hired in or after the merger year are dropped, so both series follow the
    * pre-merger cohort
    keep if min_year < acquired_year

* Flag post-merger years and save the panel; min_year is not used below
    gen post_merger = (event_time>=0)
    drop min_year
    save data/output/fig6_adviser_panel, replace


********************************************************************************
* Cleanup: delete intermediate files
********************************************************************************

* Erase intermediate files
    erase data/output/mergerreal_puresep.dta
    erase data/output/counterfactual_employeesreal_puresep.dta
    erase data/output/fig6_cohort_employees.dta
    erase data/output/employment_counterfactualreal_puresep.dta
    erase data/output/employment_counterfactual_disclosuresreal_puresep.dta

* Report completion
    di "Pure separation data construction complete!"
    di "Output: data/output/fig6_adviser_panel.dta"
