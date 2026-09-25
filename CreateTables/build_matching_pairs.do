********************************************************************************
* Finds a pseudo target and a pseudo acquirer for each merger among firms that
* never merge, matched on line of business, misconduct and employee deciles in
* the year before the merger. Writes pseudo_merger_pairs.dta,
* merger_pairs_long.dta and merger_pairs_unique.dta.
********************************************************************************

clear


********************************************************************************
* Matching criteria
********************************************************************************

* Merger list
    do "$PKG/_rules/merger_window.do" mergeryear load "data/output/merger_sample"
    keep acquirercrds mergeryear target_crd
    ren (acquirercrds mergeryear) (acquirer_crd acquired_year)
    save data/output/mergers, replace

* Misconduct per employee and its one- to three-year lags
    use data/output/firm_year_panel, clear
    xtset crd_number year
    drop if employees ==.
    gen stockdisc = any_intensity_three/employees
    gen flow_disc1 = l.stockdisc
    gen flow_disc2 = l2.stockdisc
    gen flow_disc3 = l3.stockdisc
    foreach x in flow_disc1 flow_disc2 flow_disc3{
        replace `x' = 0 if `x'==.
    }
    save data/output/firm_year_panel_ltd, replace

* Firm-years eligible to serve as matches
    use data/output/firm_adv_controls, clear
    do "$PKG/_rules/firm_year_gate.do" gate matching
    cap drop year
    ren fiscal_year year
    keep organizationcrd year
    save data/output/matching_criteria, replace // firm-years eligible for matching

* Add business lines
    use "data/output/businesslines", clear
    ren crd organizationcrd
    merge 1:1 organizationcrd year using data/output/matching_criteria
    keep if _m ==3
    drop _m
    save data/output/matching_criteria, replace // adds the firm's business lines

* Add the misconduct measures, with missing disclosures set to zero
    use data/output/matching_criteria, clear
    ren organizationcrd crd
    xtset crd year
    ren crd crd_number
    merge 1:1 crd_number year using "data/output/firm_year_panel_ltd"
    keep if _m ==3
    drop _m
    foreach x in  stockdisc flow_disc1 flow_disc2 flow_disc3 ///
       {
        replace `x' = 0  if `x' == .
    }

* Add misconduct halves and employee deciles as matching criteria
    ren (stockdisc flow_disc1 flow_disc2 flow_disc3) (fraction_bad_a changeone changetwo changethree)
    egen misc_decile = xtile(fraction_bad_a), nquant(2) by(year) // binary: above or below the yearly median
    egen misc_decile_flow1 = xtile(changeone), nquant(2) by(year)
    egen misc_decile_flow2 = xtile(changetwo), nquant(2) by(year)
    egen misc_decile_flow3 = xtile(changethree), nquant(2) by(year)
    egen employee_decile = xtile(employees), nquant(10) by(year)
    gen acquired_year = year +1
    save data/output/matching_criteria, replace


********************************************************************************
* Real firms and the pool of potential matches
********************************************************************************

* Real targets with their matching criteria
    use data/output/mergers, clear
    keep target_crd acquired_year
    duplicates drop
    ren target_crd crd_number
    merge 1:1 crd_number acquired_year using data/output/matching_criteria
    keep if _m ==3
    drop _m
    ren crd_number target_crd
    save data/output/real_target, replace // real targets with their matching criteria

* Real acquirers with their matching criteria
    use data/output/mergers, clear
    keep acquirer_crd acquired_year
    duplicates drop
    ren acquirer_crd crd_number
    merge 1:1 crd_number acquired_year using data/output/matching_criteria
    keep if _m ==3
    drop _m
    ren crd_number acquirer_crd
    save data/output/real_acquirer, replace // real acquirers with their matching criteria

* Drop firms that are ever targets or acquirers from the pool of potential matches
    do "$PKG/_rules/event_list.do" never_merged
    merge 1:m crd_number using data/output/matching_criteria
    keep if _m ==2
    drop _m
    save data/output/matching_criteria_two, replace // firms eligible to be pseudo targets or acquirers


********************************************************************************
* Counterfactual targets
********************************************************************************

* Join each real target to candidates in the same matching cells
    use data/output/real_target, clear
    ren fraction_bad_a fraction_bad_a_target
    ren changeone changeone_target
    ren changetwo changetwo_target
    ren changethree changethree_target
    keep target_crd industry acquired_year misc_decile misc_decile_flow1 ///
         misc_decile_flow2 misc_decile_flow3 employee_decile  fraction_bad_a_target ///
         changeone_target changetwo_target changethree_target
    joinby industry acquired_year misc_decile misc_decile_flow1 misc_decile_flow2 misc_decile_flow3 employee_decile ///
           using data/output/matching_criteria_two, unmatched(master)
    drop _m
    drop if fraction_bad_a ==.

* Distance: sum of standardized gaps in misconduct and its lags
    gen distance = abs(fraction_bad_a - fraction_bad_a_target)
    gen distanceone = abs(changeone_target - changeone)
    gen distancetwo = abs(changetwo_target - changetwo)
    gen distancethree = abs(changethree_target - changethree)
    foreach x in distance distanceone distancetwo distancethree{
        egen `x'z = std(`x')
    }
    egen alldistance = rowtotal(distancez distanceonez distancetwoz distancethreez)
    drop if alldistance ==.|crd_number ==.

* Keep the closest candidate for each target and count each pseudo target's matches
    sort target_crd  acquired_year  alldistance
    do "$PKG/_rules/dedup_key.do" select "target_crd acquired_year" "alldistance crd_number" 1
    bys crd_number: egen unique_match = nvals(target_crd)
    do "$PKG/_rules/dedup_key.do" select "target_crd acquired_year" "unique_match crd_number" 1
    ren (crd_number) (pseudo_target)
    keep target_crd pseudo_target acquired_year
    drop if pseudo_target == .
    bys pseudo_target: gen count_matches_target = _N
    save data/output/counterfactual_target, replace


********************************************************************************
* Counterfactual acquirers
********************************************************************************

* Join each real acquirer to candidates in the same matching cells
    use data/output/real_acquirer, clear
    ren fraction_bad_a fraction_bad_a_acq
    ren changeone changeone_acq
    ren changetwo changetwo_acq
    ren changethree changethree_acq
    keep acquirer_crd industry acquired_year misc_decile misc_decile_flow1 ///
         misc_decile_flow2 misc_decile_flow3 employee_decile fraction_bad_a_acq ///
         changeone_acq changetwo_acq changethree_acq
    joinby industry acquired_year misc_decile misc_decile_flow1 misc_decile_flow2 misc_decile_flow3  employee_decile ///
           using data/output/matching_criteria_two, unmatched(master)
    drop _m
    drop if fraction_bad_a ==.

* Distance: sum of standardized gaps in misconduct and its lags
    gen distance = abs(fraction_bad_a - fraction_bad_a_acq)
    gen distanceone = abs(changeone_acq - changeone)
    gen distancetwo = abs(changetwo_acq - changetwo)
    gen distancethree = abs(changethree_acq - changethree)
    foreach x in distance distanceone distancetwo distancethree{
        egen `x'z = std(`x')
    }
    egen alldistance = rowtotal(distancez distanceonez distancetwoz distancethreez)
    drop if alldistance ==.|crd_number ==.

* Keep the closest candidate for each acquirer and count each pseudo acquirer's matches
    sort acquirer_crd acquired_year  alldistance
    do "$PKG/_rules/dedup_key.do" select "acquirer_crd acquired_year" "alldistance crd_number" 1
    bys crd_number: egen unique_match = nvals(acquirer_crd)
    do "$PKG/_rules/dedup_key.do" select "acquirer_crd acquired_year" "unique_match crd_number" 1
    ren (crd_number) (pseudo_acquirer)
    keep acquirer_crd pseudo_acquirer acquired_year
    drop if pseudo_acquirer == .
    bys pseudo_acquirer acquired_year: gen count_matches_acquirer = _N
    save data/output/counterfactual_acquirer, replace


********************************************************************************
* Pseudo merger pairs
********************************************************************************

* Pair each merger with its pseudo target and pseudo acquirer
    use data/output/mergers, clear
    joinby target_crd using data/output/counterfactual_target
    joinby acquirer_crd acquired_year using data/output/counterfactual_acquirer
    keep target_crd acquired_year acquirer_crd pseudo_target pseudo_acquirer
    duplicates drop
    ren (target_crd acquirer_crd pseudo_target pseudo_acquirer) (real_target real_acquirer target_crd acquirer_crd)
    bys target_crd acquirer_crd acquired_year : gen count_matches = _N
    save data/output/pseudo_merger_pairs, replace

* Long format: count 0 = real target, 1 = pseudo target, 2 = pseudo acquirer, 3 = real acquirer
    use data/output/pseudo_merger_pairs, clear
    ren real_target crd0
    ren target_crd crd1
    ren acquirer_crd crd2
    ren real_acquirer crd3
    drop count_matches
    gen id = _n
    save data/output/merger_pairs_long, replace
    use data/output/merger_pairs_long, clear
    reshape long crd, i(id) j(count)
    save data/output/merger_pairs_long, replace

* Unique firm-years across all pairs
    keep crd acquired_year
    duplicates drop
    save data/output/merger_pairs_unique, replace
