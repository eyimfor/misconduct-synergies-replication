********************************************************************************
* Builds the panel of advisers who worked for each target firm around its merger
* and estimates their separation probability: Table X Panel A
* (fired_post_target.tex) and Figure 5 Panel A (Figure5_Target_DiD.png).
********************************************************************************
clear


********************************************************************************
* Import and clean data
********************************************************************************

* Load the merger sample, one row per target-acquirer pair
    use target_crd acquirercrds mergeryear using data/output/merger_sample, clear
    ren (acquirercrds mergeryear) (acquirer_crd acquired_year)
    recast int acquired_year
    keep acquirer_crd target_crd acquired_year
    bys target_crd acquirer_crd (acquired_year): keep if _n == 1
    do "$PKG/_helpers/restrict_acquired_year.do"
    keep target_crd acquirer_crd acquired_year
    save data/output/temp_one2, replace


********************************************************************************
* Create cross-section and panel data of brokers working for the target company
********************************************************************************

* Keep brokers that worked for target in the three years before the merger
    use data/output/temp_one2, clear
    keep target_crd acquired_year
    duplicates drop
    bys target_crd (acquired_year): keep if _n == 1
    ren target_crd crd_number
    merge 1:m crd_number using data/output/adviser_firm_year
    keep if _m == 3
    drop _m
    ren crd_number target_crd

* Must be working there within three years of the acquisition
    bys b_crd_number target_crd: egen min_year = min(year)
    bys b_crd_number target_crd: egen max_year = max(year)
    gen event_timelb = min_year - acquired_year
    gen event_timeub = max_year - acquired_year
    do "$PKG/_helpers/restrict_event_time.do" // At the firm at some point in the three years before the merger
    keep b_crd_number target_crd min_year
    duplicates drop
    save data/output/target_employeescs2, replace

* Track these brokers following the merger
    use data/output/target_employeescs2, clear
    joinby target_crd using data/output/temp_one2
    drop acquirer_crd
    duplicates drop
    expand 11, gen(year) // event years -5 to +5; trimmed below to years the adviser was at the firm
    do "$PKG/_rules/event_panel.do" year "b_crd_number target_crd" 6
    do "$PKG/_helpers/restrict_last_year.do"  // This is the last year of data collection
    keep if year >=min_year
    keep b_crd_number target_crd year
    duplicates drop
    save data/output/target_employeesp2, replace


********************************************************************************
* Add employer information, misconduct data, exams, and broker experience
********************************************************************************

* Generate separation indicator from next year's employer
    use data/output/target_employeesp2, clear
    replace year = year+1
    joinby b_crd_number year using data/output/adviser_firm_year, unmatched(master)
    drop _m
    gen separation = (target_crd!=crd_number)
    sort b_crd_number year
    gen left_industry = (crd_number == .)

* Moves to the acquirer after the merger do not count as separations
    joinby target_crd using data/output/temp_one2
    gen worked_for_acquirer = ((crd_number == acquirer_crd) & (acquirer_crd!=.)) //worked for acquirer following merger
    keep b_crd_number target_crd acquired_year year separation worked_for_acquirer left_industry
    replace year = year - 1
    gen event_time = year -acquired_year
    replace separation = 0 if separation == 1 & worked_for_acquirer == 1 & event_time >=0
    drop event_time
    drop acquired_year
    duplicates drop
    do "$PKG/_rules/dedup_key.do" select "b_crd_number target_crd year" "separation" 1
    save data/output/employment_target2, replace

* Add misconduct data
    use data/output/rr_disclosures_panel, clear
    merge 1:m b_crd_number year using data/output/employment_target2
    drop if _m ==1 // _m ==2 is brokers with no misconduct ever
    drop _m

* Replace missing disclosures with zero
    foreach x in settlement_amountd cumulative_disclosures ///
                 cumulative_disclosures_egan egan_intensity any_intensity any_intensity_sum egan_intensity_sum {
        replace `x' = 0  if `x' == .
    }
    save data/output/employment_target_disclosures2, replace

* Add broker exams
    use data/output/employment_target_disclosures2, clear
    merge m:1 b_crd_number year using data/output/exam_qualifications
    drop if _m ==2 // exam records with no matching adviser-year
    drop _m
    replace otherquals = 0 if otherquals ==.
    save data/output/employment_target_disclosures2, replace

* Add broker experience (years since first appearance)
    use data/output/adviser_firm_year, clear
    bys b_crd_number: egen min_year = min(year)
    keep b_crd_number min_year
    bys b_crd_number (min_year): keep if _n ==1
    merge 1:m b_crd_number using data/output/employment_target_disclosures2
    keep if _m ==3
    drop _m

* Experience and qualification counts
    gen experience  = year - min_year + 1
    gen ln_experience = ln(experience+1)
    egen cum_exams = rowtotal(investmentadviserexam_m securitiesagentstatelaw_m generalsecrep_m investmentcompanyprep_m gensecprincipal_m)
    replace cum_exams = cum_exams + otherquals
    gen ln_qualifications = ln(cum_exams+1)

* Standardize control variables and flag employees with misconduct
    foreach x in   ln_experience ln_qualifications {
        egen `x'_z = std(`x')
        _crcslbl `x'_z `x'
    }
    gen any_intensity_sum_z = (any_intensity>0)
    gen egan_intensity_sum_z = (egan_intensity>0)

* Label variables, scale separation to percent, and save the panel
    la var any_intensity_sum_z "Employees with misconduct (All)"
    la var egan_intensity_sum_z "Employees with misconduct (Egan)"
    la var ln_experience_z "Ln(Experience)"
    la var ln_qualifications_z "Ln(\# Qualifications)"
    replace separation = separation * 100
    save data/output/separation_all_panel2, replace


********************************************************************************
* Get data ready for regressions
********************************************************************************

* Attach each target's merger year and acquirer to the panel
    use data/output/temp_one2, clear
    ren acquired_year mergeryear
    ren target_crd crd
    ren acquirer_crd acquirercrds
    keep mergeryear crd acquirercrds
    ren crd target_crd
    do "$PKG/_rules/dedup_key.do" select "target_crd" "mergeryear acquirercrds" 1
    ren mergeryear acquired_year
    merge 1:m target_crd using data/output/separation_all_panel2
    keep if _m ==3
    drop _m

* Event time and sample restrictions
    egen uniqueacquirer = group(target_crd)
    gen event_time = (year - acquired_year)
    gen post_merger = (event_time>=0)
    do "$PKG/_helpers/restrict_event_time.do" // At the firm at some point in the three years before the merger
    do "$PKG/_helpers/restrict_acquired_year.do" // Mergers completed 2011-2020
    do "$PKG/_helpers/restrict_last_year.do"  // This is the last year of data collection

* Drop adviser-years after the first separation
    bys b_crd_number target_crd: egen min_sep = min(year) if separation
    bys b_crd_number target_crd: egen min_separation = min(min_sep)
    bys b_crd_number target_crd: egen max_year = max(year)
    replace min_separation = max_year if min_separation ==.
    keep if year <=min_separation
    drop min_sep min_separation max_year

* Keep events with at least one pre-merger (t <= -1) and one post-merger (t >= 0) adviser observation
    bys uniqueacquirer acquired_year: egen min_event = min(event_time)
    bys uniqueacquirer acquired_year: egen max_event = max(event_time)
    do "$PKG/_helpers/restrict_event_time.do" // At least some pre-merger data
    bys target_crd: egen count_employees = nvals(b_crd_number) if post == 0
    bys target_crd: egen count_employees_m = max(count_employees)

* Build the interaction terms, keep brokers or advisers, and save
    gen interaction_one = any_intensity_sum_z*post_merger
    gen interaction_two = egan_intensity_sum_z*post_merger
    la var any_intensity_sum_z "Employee misconduct (All)"
    la var egan_intensity_sum_z "Employee misconduct (EMS)"
    la var interaction_one "Employee misconduct (All) $\times$ Post"
    la var interaction_two "Employee misconduct (EMS) $\times$ Post"
    do "$PKG/_helpers/adviser_filter_qualified.do"  // Keep brokers or advisers
    save data/output/regressionbrokerstarget2, replace

* Keep 2009 onward and replace the qualification control with the exam summary count
    use data/output/regressionbrokerstarget2, clear
    keep if year >=2009
    cap drop ln_qualifications_z ln_qualifications cum_exams
    merge m:1 b_crd_number year using data/output/exam_summary
    keep if _m ==3
    drop _m
    cap drop ln_qualifications_z ln_qualifications
    gen ln_qualifications = ln(cum_exams)
    egen ln_qualifications_z = std(ln_qualifications)
    la var ln_qualifications_z "Ln(\# Qualifications)"
    save data/output/regressionbrokerstarget, replace


********************************************************************************
* Table X Panel A regressions
********************************************************************************

* Outcome, fixed effects, cluster and control sets
    use data/output/regressionbrokerstarget, clear
    local fe2 target_crd##year
    local clustervar target_crd
    local indepvar1  separation
    local controls     interaction_one any_intensity_sum_z
    local controls1  interaction_one any_intensity_sum_z ///
          ln_experience_z ln_qualifications_z
    local controls2    interaction_two egan_intensity_sum_z
    local controls3   interaction_two egan_intensity_sum_z ///
          ln_experience_z ln_qualifications_z

* Estimate the regressions
    eststo clear
    eststo: reghdfe `indepvar1' `controls', absorb(`fe2') vce(cluster `clustervar')
    eststo: reghdfe `indepvar1' `controls1', absorb(`fe2') vce(cluster `clustervar')
    eststo: reghdfe `indepvar1' `controls2', absorb(`fe2') vce(cluster `clustervar')
    eststo: reghdfe `indepvar1' `controls3', absorb(`fe2') vce(cluster `clustervar')

* Export the table
    esttab _all using "tables/fired_post_target.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(interaction_one interaction_two any_intensity_sum_z egan_intensity_sum_z) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst


********************************************************************************
* Figure 5 Panel A: DiD event study of separation by misconduct status
********************************************************************************

* Load the target panel from 2009 with misconduct indicators
    do "$PKG/_rules/calendar_window.do" target_did

* Keep event time window for event study
    keep if event_time >=-3 & event_time <=3

* Create interaction terms for each event time period with misconduct status
* (has_misconduct_egan is the treatment indicator)
    forvalues i=3(-1)1{
        gen pre_`i'=(event_time==-`i' & has_misconduct_egan ==1)
    }

* Interaction for current period
    gen current=(event_time==0 & has_misconduct_egan ==1)

* Interaction for the post period
    forvalues i=1(1)3{
        gen post_`i'=(event_time==`i' & has_misconduct_egan ==1)
    }

* Estimate the event study, omitting t=-1 as base period (standard DiD normalization)
    eststo clear
    replace pre_1=0
    reghdfe separation pre_3 pre_2 pre_1 current ///
            post_1 post_2 post_3 has_misconduct_egan ///
            ln_experience_z ln_qualifications_z ///
            , absorb(target_crd##year) vce(cluster target_crd)

* Plot regression coefficients
    coefplot, keep(pre_* current post_*) levels(95) vertical lcolor(black) mcolor(black) ///
              coeflabels(pre_3 = "-3" pre_2 = "-2" pre_1 = "-1" current = "0" post_1= "1" post_2= "2" post_3= "3") ///
              omitted msymbol(line) recast(connect) ///
              ytitle("Has Misconduct X t", size(medium)) ///
              ylabel(, labsize(small) angle(horizontal) nogrid format(%3.1f)) ///
              yline(0, lwidth(vthin) lpattern(solid) lcolor(black)) ///
              xtitle("Years Relative to Merger", size(medium)) ///
              xlabel(,labsize(small)) graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) ///
              ciopts(recast(rcap) lpattern(dash) lcolor(navy)) ///
              xline(4, lwidth(vthin) lpattern(dash) lcolor(black))

* Fix the canvas at 7.5 x 4.5 in (720 x 432 px): Stata's default graph size differs by version
    graph display, xsize(7.5) ysize(4.5)
    graph export "figures/Figure5_Target_DiD.png", as(png) width(720) replace
