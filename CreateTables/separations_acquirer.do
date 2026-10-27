********************************************************************************
* Separation probability of acquirer advisers around mergers: Table X, Panel B
* (tables/fired_post_acquirer.tex) and Figure 5, Panel B
* (figures/Figure5_Acquirer_DiD.png).
********************************************************************************
clear


********************************************************************************
* Advisers who worked for the acquirer
********************************************************************************

* Link each acquirer to the advisers it employed
    use data/output/temp_one2, clear
    do "$PKG/_rules/merger_window.do" acquired_year project "acquirer_crd acquired_year"
    duplicates drop
    ren acquirer_crd crd_number
    joinby crd_number using data/output/adviser_firm_year
    ren crd_number acquirer_crd
    save  data/output/brokeracquirer, replace

* Keep advisers at the acquirer at some point in the three years before the merger
    use data/output/brokeracquirer, clear
    bys b_crd_number acquirer_crd acquired_year: egen min_year = min(year)
    bys b_crd_number acquirer_crd acquired_year: egen max_year = max(year)
    gen event_timelb = min_year - acquired_year
    gen event_timeub = max_year - acquired_year
    do "$PKG/_helpers/restrict_event_time.do"
    keep b_crd_number acquirer_crd  acquired_year min_year
    duplicates drop
    save  data/output/acquirers_employeescs, replace

* Expand to a panel of event years -5 to +5, trimmed to years the adviser was at the firm
    use data/output/acquirers_employeescs, clear
    expand 11, gen(year)
    do "$PKG/_rules/event_panel.do" year "b_crd_number acquirer_crd" 6
    do "$PKG/_helpers/restrict_last_year.do"  // last year of data collection
    keep if year >=min_year // the panel cannot start before the adviser joined the firm
    keep b_crd_number acquirer_crd acquired_year year
    duplicates drop
    save data/output/acquirer_employeesp, replace


********************************************************************************
* Separations, misconduct, exams and experience
********************************************************************************

* Flag a separation when next year's employer is not the acquirer, and flag moves
* to the target
    use data/output/acquirer_employeesp, clear
    replace year = year+1
    joinby b_crd_number year using data/output/adviser_firm_year, unmatched(master)
    drop _m
    gen separation = (crd_number!=acquirer_crd)
    joinby acquirer_crd acquired_year using data/output/temp_one2
    gen worked_for_target = ((crd_number != acquirer_crd) & (crd_number == target_crd) & (acquirer_crd!=.)) // worked for the target after the merger

* Do not count post-merger moves to the target as separations
    keep b_crd_number acquirer_crd acquired_year year separation worked_for_target
    replace year = year - 1
    do "$PKG/_rules/separation.do" partner "worked_for_target"
    duplicates drop
    do "$PKG/_rules/dedup_key.do" select "b_crd_number acquirer_crd acquired_year year" "separation" 1
    save data/output/employment_acquirer, replace

* Add misconduct data and set missing disclosures to zero
    use data/output/rr_disclosures_panel, clear
    merge 1:m b_crd_number year using data/output/employment_acquirer
    drop if _m ==1 // _m ==2 is advisers with no misconduct ever
    drop _m
    foreach x in settlement_amountd cumulative_disclosures ///
                 cumulative_disclosures_egan egan_intensity any_intensity any_intensity_sum egan_intensity_sum {
        replace `x' = 0  if `x' == .
    }
    save data/output/employment_acq_disclosures, replace

* Add adviser exams
    use data/output/employment_acq_disclosures, clear
    merge m:1 b_crd_number year using data/output/exam_qualifications
    drop if _m ==2 // exam records with no matching adviser-year
    drop _m
    replace otherquals = 0 if otherquals ==.
    save data/output/employment_acq_disclosures, replace

* Add each adviser's first year in the employment data
    use data/output/adviser_firm_year, clear
    bys b_crd_number: egen min_year = min(year)
    keep b_crd_number min_year
    bys b_crd_number (min_year): keep if _n ==1
    merge 1:m b_crd_number using data/output/employment_acq_disclosures
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

* Define event time, post-merger and misconduct indicators
    gen event_time = year - acquired_year
    gen post_merger = (event_time>=0)
    gen any_intensity_sum_z = (any_intensity>0)
    gen egan_intensity_sum_z = (egan_intensity>0)

* Label variables and scale separation to percent
    la var any_intensity_sum_z "Employees with misconduct (All)"
    la var egan_intensity_sum_z "Employees with misconduct (Egan)"
    la var ln_experience_z "Ln(Experience)"
    la var ln_qualifications_z "Ln(\# Qualifications)"
    replace separation = separation * 100

* Apply the merger-year and event-time restrictions and drop duplicates
    do "$PKG/_helpers/restrict_acquired_year.do" // mergers completed 2011-2020
    do "$PKG/_helpers/restrict_event_time.do" // event years -3 to +3
    duplicates drop
    save data/output/separation_acq_panel, replace


********************************************************************************
* Regression sample
********************************************************************************

* Keep advisers of acquirers in the merger sample
    use data/output/temp_one2, clear
    keep acquirer_crd acquired_year
    duplicates drop
    merge 1:m acquirer_crd acquired_year using  data/output/separation_acq_panel
    keep if _m ==3
    drop _m
    egen uniqueacquirer = group(acquirer_crd)

* Keep events with at least one pre-merger (t <= -1) and one post-merger (t >= 0) adviser observation
    bys uniqueacquirer acquired_year: egen min_event = min(event_time)
    bys uniqueacquirer acquired_year: egen max_event = max(event_time)
    do "$PKG/_helpers/restrict_event_time.do" // events observed before and after the merger; event years -3 to +3
    do "$PKG/_helpers/restrict_acquired_year.do" // mergers completed 2011-2020
    do "$PKG/_helpers/restrict_last_year.do"  // last year of data collection

* Drop adviser-years after the first separation
    do "$PKG/_rules/separation.do" censor "b_crd_number acquirer_crd"
    replace min_separation = max_year if min_separation ==.
    keep if year <=min_separation

* Build the misconduct x post interactions and keep brokers or advisers
    gen interaction_one = any_intensity_sum_z*post_merger
    gen interaction_two = egan_intensity_sum_z*post_merger
    la var any_intensity_sum_z "Employees with misconduct (All)"
    la var egan_intensity_sum_z "Employees with misconduct (EMS)"
    la var interaction_one "Employees with misconduct (All) $\times$ Post"
    la var interaction_two "Employees with misconduct (EMS) $\times$ Post"
    do "$PKG/_helpers/adviser_filter_qualified.do"  // keep brokers or advisers
    save data/output/regressionbrokersacq, replace

* Keep years from 2009 on and rebuild the qualification count from the exam summary
    use data/output/regressionbrokersacq, clear
    keep if year >=2009
    cap drop ln_qualifications_z ln_qualifications cum_exams
    merge m:1 b_crd_number year using data/output/exam_summary
    keep if _m ==3
    drop _m
    cap drop ln_qualifications_z ln_qualifications
    gen ln_qualifications = ln(cum_exams)
    egen ln_qualifications_z = std(ln_qualifications)
    la var ln_qualifications_z "Ln(\# Qualifications)"
    save data/output/regressionbrokersacq, replace


********************************************************************************
* Table X, Panel B regressions
********************************************************************************

* Set the outcome, the acquirer-by-year fixed effect and clustering by acquirer
    use data/output/regressionbrokersacq, clear
    local fe2   acquirer_crd##year
    local clustervar acquirer_crd
    local indepvar1  separation

* Regressor lists for the four specifications
    local controls     interaction_one any_intensity_sum_z
    local controls1  interaction_one any_intensity_sum_z   ///
                     ln_experience_z ln_qualifications_z
    local controls2    interaction_two egan_intensity_sum_z
    local controls3   interaction_two egan_intensity_sum_z  ///
                      ln_experience_z ln_qualifications_z

* Estimate the four specifications
    eststo clear
    eststo: reghdfe `indepvar1' `controls' , absorb(`fe2') vce(cluster `clustervar')
    eststo: reghdfe `indepvar1' `controls1', absorb(`fe2') vce(cluster `clustervar')
    eststo: reghdfe `indepvar1' `controls2', absorb(`fe2') vce(cluster `clustervar')
    eststo: reghdfe `indepvar1' `controls3', absorb(`fe2') vce(cluster `clustervar')

* Export the table
    esttab _all using "tables/fired_post_acquirer.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(interaction_one interaction_two any_intensity_sum_z egan_intensity_sum_z) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst


********************************************************************************
* Figure 5, Panel B: difference-in-differences event study of separation by
* misconduct status
********************************************************************************

* Flag advisers with misconduct and keep event years -3 to +3
    use data/output/regressionbrokersacq, clear
    gen has_misconduct_any = (any_intensity_sum>0)
    gen has_misconduct_egan = (egan_intensity_sum>0)
    keep if event_time >=-3 & event_time <=3

* Interact each pre-merger event year with misconduct status (EMS)
    forvalues i=3(-1)1{
        gen pre_`i'=(event_time==-`i' & has_misconduct_egan ==1)
    }

* Interaction for the merger year
    gen current=(event_time==0 & has_misconduct_egan ==1)

* Interactions for the post-merger years
    forvalues i=1(1)3{
        gen post_`i'=(event_time==`i' & has_misconduct_egan ==1)
    }

* Estimate the event study, omitting t = -1 as the base period
    eststo clear
    replace pre_1=0
    reghdfe separation pre_3 pre_2 pre_1 current ///
            post_1 post_2 post_3 has_misconduct_egan ///
            ln_experience_z ln_qualifications_z ///
            , absorb(acquirer_crd##year) vce(cluster acquirer_crd)

* Plot the coefficients
    coefplot, keep(pre_* current post_*) levels(95) vertical lcolor(black) mcolor(black) ///
              coeflabels(pre_3 = "-3" pre_2 = "-2" pre_1 = "-1" current = "0" post_1= "1" post_2= "2" post_3= "3") ///
              omitted msymbol(line) recast(connect) ///
              ytitle("Has Misconduct (EMS) X t", size(medium)) ///
              ylabel(, labsize(small) angle(horizontal) nogrid format(%3.1f)) ///
              yline(0, lwidth(vthin) lpattern(solid) lcolor(black)) ///
              xtitle("Years Relative to Merger", size(medium)) ///
              xlabel(,labsize(small)) graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) ///
              ciopts(recast(rcap) lpattern(dash) lcolor(navy)) ///
              xline(4, lwidth(vthin) lpattern(dash) lcolor(black))

* Fix the canvas at 7.5 x 4.5 in (720 x 432 px), since Stata's default graph size differs by version
    graph display, xsize(7.5) ysize(4.5)
    graph export "figures/Figure5_Acquirer_DiD.png", as(png) width(720) replace
