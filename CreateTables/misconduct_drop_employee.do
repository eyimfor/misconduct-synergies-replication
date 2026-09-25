********************************************************************************
* Table XI: new disclosures by target advisers after the merger, relative to
* matched control advisers. Builds the adviser-year separation and disclosure
* panel (separation_all_counterfactual, regressioncounterfactual) and writes
* tables/drop_disclosures.tex.
********************************************************************************
clear


********************************************************************************
* Advisers who worked for the target
********************************************************************************

* Keep merger pairs in the sample window
    use data/output/merger_pairs_unique, clear
    do "$PKG/_rules/merger_window.do" acquired_year filter
    save data/output/merger_pairs_window, replace

* Keep advisers who worked for the target in the five years before the acquisition
    use data/output/merger_pairs_window, clear
    ren crd crd_number
    joinby crd_number using data/output/adviser_firm_year
    bys b_crd_number crd_number: egen min_year = min(year)
    gen event_time = year - acquired_year
    keep if event_time >=-5 & event_time <=-1
    keep b_crd_number crd_number min_year
    duplicates drop
    save data/output/target_employees_pre, replace

* Attach each adviser's merger pairs and expand to one row per year around the merger
    use data/output/target_employees_pre, clear
    ren crd_number crd
    joinby crd using data/output/merger_pairs_window
    duplicates drop
    expand 15, gen(year) // trimmed to event years -5 to +5 below
    do "$PKG/_rules/event_panel.do" year "b_crd_number crd" 8

* Trim the panel to event years -5 to +5 while the adviser was in the data, through 2022
    keep if year <= 2022
    keep if year >=min_year
    gen event_time = year - acquired_year
    keep if event_time >=-5 & event_time <=5
    keep b_crd_number crd year
    duplicates drop
    ren crd crd_number
    save data/output/counterfactual_employeesp, replace


********************************************************************************
* Separations, misconduct, exams and experience
********************************************************************************

* Take next year's employer and flag separation and leaving the industry
    use data/output/counterfactual_employeesp, clear
    replace year = year+1
    ren crd_number crd_number_prev
    joinby b_crd_number year using data/output/adviser_firm_year, unmatched(master)
    drop _m
    gen separation = (crd_number!=crd_number_prev)
    sort b_crd_number year
    gen left_industry = (crd_number == .)

* Do not count moves to the acquirer as separations
    ren crd_number_prev target_crd
    joinby target_crd using data/output/temp_one2, unmatched(master)
    drop _m
    gen worked_for_acquirer = ((crd_number == acquirer_crd) & (acquirer_crd!=.)) // worked for the acquirer after the merger
    keep b_crd_number target_crd acquired_year year separation worked_for_acquirer left_industry
    replace year = year - 1
    replace separation = 0 if separation == 1 & worked_for_acquirer == 1

* Keep one record per adviser, firm and year
    drop acquired_year
    duplicates drop
    ren target_crd crd
    do "$PKG/_rules/dedup_key.do" select "b_crd_number crd year" "separation" 1
    save data/output/employment_counterfactual, replace

* Add misconduct data and set missing disclosures to zero
    use data/output/rr_disclosures_panel, clear
    merge 1:m b_crd_number year using data/output/employment_counterfactual
    drop if _m ==1 // _m ==2 is advisers with no misconduct ever
    drop _m
    foreach x in settlement_amountd cumulative_disclosures ///
                 cumulative_disclosures_egan egan_intensity any_intensity any_intensity_sum egan_intensity_sum {
        replace `x' = 0  if `x' == .
    }
    save data/output/employment_counterfactual_disclosures, replace

* Add adviser exams
    use data/output/employment_counterfactual_disclosures, clear
    merge m:1 b_crd_number year using data/output/exam_qualifications
    drop if _m ==2 // exam records with no matching adviser-year
    drop _m
    replace otherquals = 0 if otherquals ==.
    save data/output/employment_counterfactual_disclosures, replace

* Add each adviser's first year in the employment data
    use data/output/adviser_firm_year, clear
    bys b_crd_number: egen min_year = min(year)
    keep b_crd_number min_year
    bys b_crd_number (min_year): keep if _n ==1
    merge 1:m b_crd_number using data/output/employment_counterfactual_disclosures
    keep if _m ==3
    drop _m

* Compute experience and the qualification count
    gen experience  = year - min_year + 1
    gen ln_experience = ln(experience+1)
    egen cum_exams = rowtotal(investmentadviserexam_m securitiesagentstatelaw_m generalsecrep_m investmentcompanyprep_m gensecprincipal_m)
    replace cum_exams = cum_exams + otherquals
    gen ln_qualifications = ln(cum_exams+1)

* Standardize control variables
    foreach x in   ln_experience ln_qualifications {
        egen `x'_z = std(`x')
        _crcslbl `x'_z `x'
    }

* Flag adviser-years with any misconduct (All and EMS)
    gen any_intensity_sum_z = (any_intensity>0)
    gen egan_intensity_sum_z = (egan_intensity>0)

* Label variables, scale separation to percent and save the panel
    la var any_intensity_sum_z "Employees with misconduct (All)"
    la var egan_intensity_sum_z "Employees with misconduct (Egan)"
    la var ln_experience_z "Ln(Experience)"
    la var ln_qualifications_z "Ln(\# Qualifications)"
    replace separation = separation * 100
    save data/output/separation_all_counterfactual, replace


********************************************************************************
* Regression sample
********************************************************************************

* Attach the adviser panel to the merger pairs and keep event years -3 to +3 through 2022
    do "$PKG/_rules/merger_window.do" acquired_year load "data/output/merger_pairs_long"
    joinby crd using data/output/separation_all_counterfactual
    gen event_time = year - acquired_year
    keep if event_time >=-3 & event_time <=3
    keep if year <=2022

* Drop adviser-years after the first separation
    bys b_crd_number crd: egen min_sep = min(year) if separation
    bys b_crd_number crd: egen min_separation = min(min_sep)
    bys b_crd_number crd: egen max_year = max(year)
    replace min_separation = max_year if min_separation ==.
    keep if year <=min_separation
    drop min_sep min_separation max_year

* Keep firms with at least one adviser observation at t = -1 or earlier and one at t = 0 or later
    bys crd acquired_year: egen min_event = min(event_time)
    bys crd acquired_year: egen max_event = max(event_time)
    keep if min_event <=-1
    keep if max_event >=0

* Flag post-merger years and count each firm's pre-merger advisers
    gen post_merger = (event_time>=0)
    bys crd: egen count_employees = nvals(b_crd_number) if post_merger == 0
    bys crd: egen count_employees_m = max(count_employees)
    drop count_employees

* Build the misconduct x post interactions
    gen interaction_one = any_intensity_sum_z*post_merger
    gen interaction_two = egan_intensity_sum_z*post_merger
    la var any_intensity_sum_z "Employee misconduct (All)"
    la var egan_intensity_sum_z "Employee misconduct (EMS)"
    la var interaction_one "Employee misconduct (All) $\times$ Post"
    la var interaction_two "Employee misconduct (EMS) $\times$ Post"
    save data/output/regressioncounterfactual, replace


********************************************************************************
* Table XI regressions
********************************************************************************

* Keep brokers or advisers at the target or its matched control target
* (count: 0 real target, 1 control target, 2 control acquirer, 3 real acquirer)
    use data/output/regressioncounterfactual, clear
    do "$PKG/_helpers/adviser_filter_qualified.do"  // keep brokers or advisers
    gen real  = (count == 0|count == 3)
    gen target = (count == 0|count == 1)
    keep if target

* Keep pairs in which the merged and the control firm both appear in the event year
    do "$PKG/_rules/thresholds.do" twins "id event_time" real

* Build the merged x post interaction, keep mergers in the sample window and
* log the pre-merger adviser count
    cap drop interaction_one interaction_two
    gen interaction_one = post*real
    do "$PKG/_rules/merger_window.do" acquired_year filter
    gen ln_employees = ln(count_employees_m)

* Scale misconduct to percent and label variables
    replace any_intensity_sum_z = any_intensity_sum_z*100
    replace egan_intensity_sum_z = egan_intensity_sum_z*100
    la var any_intensity_sum_z "Employee misconduct (All)"
    la var egan_intensity_sum_z "Employee misconduct (EMS)"
    la var interaction_one "Merged $\times$ Post"
    la var real "Merged"

* Estimate the four specifications
    eststo clear
    eststo: reghdfe any_intensity_sum_z interaction_one real post , absorb(id##year) vce(cluster id)
    eststo: reghdfe any_intensity_sum_z interaction_one real post ln_experience_z ln_qualifications_z , absorb(id##year) vce(cluster id)
    eststo: reghdfe egan_intensity_sum_z interaction_one real post , absorb(id##year) vce(cluster id)
    eststo: reghdfe egan_intensity_sum_z interaction_one real post ln_experience_z ln_qualifications_z, absorb(id##year) vce(cluster id)

* Export the table
    esttab _all using "tables/drop_disclosures.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(interaction_one real ln_experience_z ln_qualifications_z) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst
