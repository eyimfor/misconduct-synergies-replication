********************************************************************************
* Table IX: builds the combined-firm panel around real and pseudo mergers (adviser_event_panel)
* and estimates the post-merger misconduct difference-in-differences (tables/post_misc_regs.tex).
* The stats_tables_final winsorizing step also saves misconductdroptest_*.dta, the inputs to
* Tables VII and VIII and Figure 4.
********************************************************************************
clear


********************************************************************************
* Pseudo mergers: target statistics
********************************************************************************

* Load the target firm controls, with AUM in millions
    use data/output/firm_adv_controls, clear
    ren fiscal_year year_aum
    replace dollar_aum = dollar_aum/1000000
    ren organizationcrd  target_crd
    xtset target_crd year_aum

* Rolling average AUM growth and client growth over the current and two prior years
    gen aum_growth = ((dollar_aum - l.dollar_aum)/l.dollar_aum)*100
    gen client_growth = ((number_clients - l.number_clients)/l.number_clients)*100
    rangestat (mean) aum_growth client_growth , ///
              interval(year_aum -2 0) by(target_crd)

* Attach the pseudo merger pairs to each target
    joinby target_crd using data/output/pseudo_merger_pairs

* Keep the target variables used below, within five years of the merger
    keep target_crd acquirer_crd year_aum  ///
         dollar_aum acquired_year ///
         aum_growth_mean client_growth_mean adviser_age retail_clients number_clients
    gen event_time =  year_aum - acquired_year
    keep if event_time <=5 & event_time >= -5
    duplicates drop
    save data/output/target_stats_pp_pseudo, replace


********************************************************************************
* Pseudo mergers: acquirer statistics
********************************************************************************

* Keep only the acquirer, target and acquired_year
    use  data/output/target_stats_pp_pseudo, clear
    keep acquired_year acquirer_crd target_crd
    duplicates drop
    save data/output/acquirer_data_pseudo, replace

* Load the acquirer firm controls, with AUM in millions, one filing per acquirer and year
    use data/output/firm_adv_controls, clear
    ren fiscal_year year_aum
    replace dollar_aum = dollar_aum/1000000
    ren organizationcrd  acquirer_crd
    do "$PKG/_rules/dedup_key.do" select "acquirer_crd year_aum" "date_submitted filingid" _N
    xtset acquirer_crd year_aum

* Rolling average AUM growth and client growth over the current and two prior years
    gen aum_growth = ((dollar_aum - l.dollar_aum)/l.dollar_aum)*100
    gen client_growth = ((number_clients - l.number_clients)/l.number_clients)*100
    rangestat (mean) aum_growth client_growth , ///
              interval(year_aum -2 0) by(acquirer_crd)

* Add the statistics to the merger data
    joinby acquirer_crd using data/output/acquirer_data_pseudo

* Keep the acquirer variables used below, within five years of the merger
    keep acquirer_crd acquirer_crd year_aum  ///
         dollar_aum acquired_year number_clients ///
         aum_growth_mean client_growth_mean adviser_age retail_clients target_crd
    gen event_time =  year_aum - acquired_year
    keep if event_time <=5 & event_time >= -5
    isid target_crd acquirer_crd acquired_year event_time
    save data/output/acquirer_stats_two_pseudo, replace


********************************************************************************
* Pseudo mergers: combined firm
********************************************************************************

* Build the event-time panel of pseudo pairs and add the target statistics
    do "$PKG/_rules/merger_window.do" acquired_year load "data/output/pseudo_merger_pairs" "target_crd acquirer_crd acquired_year" ""
    duplicates drop
    do "$PKG/_rules/event_panel.do" pair "target_crd acquirer_crd"
    merge 1:1 target_crd acquirer_crd acquired_year event_time using data/output/target_stats_pp_pseudo //add target statistics
    drop if _m ==2
    drop _m

* Prefix the target variables with t
    foreach x in retail_clients dollar_aum adviser_age aum_growth_mean client_growth_mean number_clients{
        ren `x' t`x'
    }
    duplicates drop

* Add the acquirer statistics
    merge 1:1 target_crd acquirer_crd acquired_year event_time using data/output/acquirer_stats_two_pseudo
    drop _m

* Fill missing ages and years forward from the previous event year
    bys id target_crd (event_time): replace tadviser_age = tadviser_age[_n-1] + 1 if tadviser_age==.
    drop if tadviser_age ==.
    bys acquirer_crd (event_time): replace adviser_age = adviser_age[_n-1] + 1 if adviser_age==.
    drop if adviser_age ==.
    bys id target_crd acquirer_crd (event_time): replace year_aum = year_aum[_n-1] + 1 if year_aum==.

* Drop rows with no AUM for either firm; set other missing quantities and growth to zero
    drop if tdollar_aum==.& dollar_aum==.
    replace tdollar_aum=0 if tdollar_aum==.
    replace dollar_aum=0 if dollar_aum==.
    replace tnumber_clients=0 if tnumber_clients==.
    replace number_clients=0 if number_clients==.
    replace aum_growth_mean=0 if aum_growth_mean==.
    replace taum_growth_mean=0 if taum_growth_mean==.
    replace client_growth_mean=0 if client_growth_mean==.
    replace tclient_growth_mean=0 if tclient_growth_mean==.

* Joint quantities for the combined firm
    foreach x in dollar_aum  number_clients {
        gen `x'c = `x' + t`x'
    }

* Fill missing retail-client flags with each firm's maximum; flag pairs where both are retail
    bys target_crd: egen miss = max(tretail_clients)
    bys acquirer_crd: egen miss2 = max(retail_clients)
    replace tretail_clients = miss if tretail_clients == .
    replace retail_clients = miss2 if retail_clients == .
    drop miss miss2
    gen both_retailc = (tretail_clients == 1 & retail_clients==1)

* Combined age and growth as the mean across the two firms
    egen combined_agec = rowmean(adviser_age tadviser_age)
    egen combined_aumg = rowmean(taum_growth_mean aum_growth_mean)
    egen combined_clg = rowmean(client_growth_mean tclient_growth_mean)

* Keep the combined-firm variables and mark the pairs as counterfactual
    keep acquired_year target_crd acquirer_crd year_aum event_time ///
         dollar_aumc number_clientsc ///
         both_retailc combined_agec combined_aumg combined_clg
    duplicates drop
    gen counterfactual = 1
    save data/output/combined_stats_pp_pseudo, replace

* Load the pseudo pairs (count 1 and 2) in wide form
    do "$PKG/_rules/merger_window.do" acquired_year load "data/output/merger_pairs_long" "" "count == 1|count==2"
    reshape wide crd, i(id acquired_year) j(count)
    ren (crd1 crd2) (target_crd acquirer_crd)

* Add the combined misconduct, one row per pair and event year
    merge 1:m id acquired_year using data/output/postmergercombinedfirmcf
    keep if _m ==3
    drop _m
    do "$PKG/_rules/dedup_key.do" select "id acquired_year event_time" "egan_misconduct any_misconduct" _N
    ren year year_aum
    duplicates drop

* Add the combined-firm statistics
    merge m:1 event_time acquired_year target_crd acquirer_crd using data/output/combined_stats_pp_pseudo
    keep if _m ==3
    drop _m
    save data/output/combined_stats_pp_pseudo, replace


********************************************************************************
* Real mergers: target statistics
********************************************************************************

* Load the target firm controls, with AUM in millions
    use data/output/firm_adv_controls, clear
    ren fiscal_year year_aum
    replace dollar_aum = dollar_aum/1000000
    ren organizationcrd  real_target
    xtset real_target year_aum

* Rolling average AUM growth and client growth over the current and two prior years
    gen aum_growth = ((dollar_aum - l.dollar_aum)/l.dollar_aum)*100
    gen client_growth = ((number_clients - l.number_clients)/l.number_clients)*100
    rangestat (mean) aum_growth client_growth , ///
              interval(year_aum -2 0) by(real_target)

* Attach the merger pairs to each real target
    joinby real_target using data/output/pseudo_merger_pairs

* Keep the target variables used below, within five years of the merger
    keep real_target real_acquirer year_aum  ///
         dollar_aum acquired_year ///
         aum_growth_mean client_growth_mean adviser_age retail_clients number_clients
    gen event_time =  year_aum - acquired_year
    keep if event_time <=5 & event_time >= -5
    save data/output/target_stats_pp_real, replace


********************************************************************************
* Real mergers: acquirer statistics
********************************************************************************

* Keep only the acquirer, target and acquired_year
    use  data/output/target_stats_pp_real, clear
    keep acquired_year real_acquirer real_target
    duplicates drop
    save data/output/acquirer_data_real, replace

* Load the acquirer firm controls, with AUM in millions, one filing per acquirer and year
    use data/output/firm_adv_controls, clear
    ren fiscal_year year_aum
    replace dollar_aum = dollar_aum/1000000
    ren organizationcrd  real_acquirer
    do "$PKG/_rules/dedup_key.do" select "real_acquirer year_aum" "date_submitted filingid" _N
    xtset real_acquirer year_aum

* Rolling average AUM growth and client growth over the current and two prior years
    gen aum_growth = ((dollar_aum - l.dollar_aum)/l.dollar_aum)*100
    gen client_growth = ((number_clients - l.number_clients)/l.number_clients)*100
    rangestat (mean) aum_growth client_growth , ///
              interval(year_aum -2 0) by(real_acquirer)

* Add the statistics to the merger data
    joinby real_acquirer using data/output/acquirer_data_real

* Keep the acquirer variables used below, within five years of the merger
    keep real_acquirer year_aum  ///
         dollar_aum acquired_year number_clients ///
         aum_growth_mean client_growth_mean adviser_age retail_clients real_target
    gen event_time =  year_aum - acquired_year
    keep if event_time <=5 & event_time >= -5
    save data/output/acquirer_stats_two_real, replace


********************************************************************************
* Real mergers: combined firm
********************************************************************************

* Build the event-time panel of real pairs and add the target statistics
    do "$PKG/_rules/merger_window.do" acquired_year load "data/output/pseudo_merger_pairs" "real_target real_acquirer acquired_year" ""
    duplicates drop
    do "$PKG/_rules/event_panel.do" pair "real_target real_acquirer"
    do "$PKG/_rules/event_panel.do" merge 1:m "real_target real_acquirer acquired_year event_time" "data/output/target_stats_pp_real"
    drop _m

* Prefix the target variables with t, then add the acquirer statistics
    foreach x in retail_clients dollar_aum adviser_age aum_growth_mean client_growth_mean number_clients{
        ren `x' t`x'
    }
    do "$PKG/_rules/event_panel.do" merge 1:m "real_target real_acquirer acquired_year event_time" "data/output/acquirer_stats_two_real"
    drop _m

* Fill missing ages and years forward from the previous event year
    bys id real_target (event_time): replace tadviser_age = tadviser_age[_n-1] + 1 if tadviser_age==.
    drop if tadviser_age ==.
    bys real_acquirer (event_time): replace adviser_age = adviser_age[_n-1] + 1 if adviser_age==.
    drop if adviser_age ==.
    bys id real_target real_acquirer (event_time): replace year_aum = year_aum[_n-1] + 1 if year_aum==.

* Drop rows with no AUM for either firm; set other missing quantities and growth to zero
    drop if tdollar_aum==.& dollar_aum==.
    replace tdollar_aum=0 if tdollar_aum==.
    replace dollar_aum=0 if dollar_aum==.
    replace tnumber_clients=0 if tnumber_clients==.
    replace number_clients=0 if number_clients==.
    replace aum_growth_mean=0 if aum_growth_mean==.
    replace taum_growth_mean=0 if taum_growth_mean==.
    replace client_growth_mean=0 if client_growth_mean==.
    replace tclient_growth_mean=0 if tclient_growth_mean==.

* Joint quantities for the combined firm
    foreach x in dollar_aum  number_clients {
        gen `x'c = `x' + t`x'
    }

* Fill missing retail-client flags with each firm's maximum; flag pairs where both are retail
    bys real_target: egen miss = max(tretail_clients)
    bys real_acquirer: egen miss2 = max(retail_clients)
    replace tretail_clients = miss if tretail_clients == .
    replace retail_clients = miss2 if retail_clients == .
    drop miss miss2
    gen both_retailc = (tretail_clients == 1 & retail_clients==1)

* Combined age and growth as the mean across the two firms
    egen combined_agec = rowmean(adviser_age tadviser_age)
    egen combined_aumg = rowmean(taum_growth_mean aum_growth_mean)
    egen combined_clg = rowmean(client_growth_mean tclient_growth_mean)

* Keep the combined-firm variables and mark the pairs as real
    keep acquired_year real_target real_acquirer year_aum event_time ///
         dollar_aumc number_clientsc ///
         both_retailc combined_agec combined_aumg combined_clg
    duplicates drop
    gen counterfactual = 0
    save data/output/combined_stats_pp_real, replace

* Load the real pairs (count 0 and 3) in wide form
    do "$PKG/_rules/merger_window.do" acquired_year load "data/output/merger_pairs_long" "" "count == 0|count==3"
    reshape wide crd, i(id acquired_year) j(count)
    ren (crd0 crd3) (real_target real_acquirer)

* Add the combined misconduct, one row per pair and event year
    merge 1:m id acquired_year using data/output/postmergercombinedfirm
    keep if _m ==3
    drop _m
    do "$PKG/_rules/dedup_key.do" select "id acquired_year event_time" "egan_misconduct any_misconduct" _N
    ren year year_aum

* Add the combined-firm statistics
    do "$PKG/_rules/event_panel.do" merge 1:1 "event_time acquired_year real_target real_acquirer" "data/output/combined_stats_pp_real"
    keep if _m ==3
    drop _m
    ren (real_target real_acquirer) (target_crd acquirer_crd)
    save data/output/combined_stats_pp_real, replace


********************************************************************************
* Stacked panel and regressions
********************************************************************************

* Stack pseudo (treated = 0) and real (treated = 1) pairs
    use data/output/combined_stats_pp_pseudo, clear
    gen treated = 0
    append using data/output/combined_stats_pp_real
    replace treated = 1 if treated == .
    egen clustervar = group(id)
    ren (any_misconduct egan_misconduct) (fraction_bad_a_flow fraction_bad_e_flow)
    egen cohort = group(id)
    gen post = (event_time >=0)

* Keep pair-years observed for both the pseudo and the real merger
    bys id event_time: egen obs = nvals(treated)
    keep if obs == 2
    drop obs

* Keep pairs observed before and after the merger, within years -3 to +3
    bys id: egen min_event = min(event_time)
    bys id: egen max_event = max(event_time)
    do "$PKG/_rules/event_panel.do" presence
    keep if event_time >=-3 & event_time <=3

* Regression variables
    gen interaction = treated*post
    gen ln_employees = ln(employees)
    gen ln_aum = ln(dollar_aum)
    egen ln_employees_std = std(ln_employees)
    egen ln_aum_std = std(dollar_aum)
    gen ln_age = ln(combined_agec)
    egen ln_age_z = std(ln_age)

* Save adviser_event_panel and the winsorized stats-table inputs
    do "$PKG/_rules/winsorize_last.do" stats_tables_final "fraction_bad_a_flow fraction_bad_e_flow combined_aumg combined_clg"

* Load the panel and label the regressors
    use data/output/adviser_event_panel, clear
    la var interaction "Merged X Post"
    la var treated "Merged"
    la var post "Post"
    la var ln_aum_std "Ln(Assets under management)"
    la var ln_age_z "Ln(Firm Age)"
    la var ln_employees_std "Ln(Number of employees)"
    la var both_retailc "Retail clients"

* Specification: year FE, clustered by cohort
    local fe1  year_aum
    local clustervar cohort
    local indepvar2  fraction_bad_a_flow
    local indepvar4  fraction_bad_e_flow
    local controls   interaction treated post
    local controls2   interaction treated post both_retailc ln_aum_std ln_age_z ln_employees_std

* Keep the regression sample, winsorize and standardize
    do "$PKG/_rules/winsorize_last.do" ix_final "fraction_bad_a_flow fraction_bad_e_flow combined_aumg combined_clg"

* Post-merger misconduct regressions, with and without controls
    eststo:  reghdfe `indepvar2' `controls', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar2' `controls2', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar4' `controls', absorb(`fe1') vce(cluster `clustervar')
    eststo:  reghdfe `indepvar4' `controls2', absorb(`fe1') vce(cluster `clustervar')

* Write the table
    esttab _all using "tables/post_misc_regs.tex", replace label  ///
           star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) ///
           order(interaction treated post) ///
           ar2  noomitted  interaction(" $\times$ ") style(tex) ///
           compress nomtitles fragment noconst
