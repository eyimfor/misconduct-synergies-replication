********************************************************************************
* Builds data/output/target_stats.dta: target-firm characteristics, employees
* and misconduct rates in the year before the merger, for Table II. Also saves
* data/output/mergers.dta.
********************************************************************************
clear

* Restrict to mergers from 2011 to 2020
    use data/output/mergers2021and2023, clear
    do "$PKG/_helpers/restrict_merger_year.do"

* Keep one merger per target. When a target has two acquirers in the same
* year, $pin_merger_tie == 1 keeps the lowest acquirer CRD (the same rule as
* stats_acquirer_firm.do); otherwise the first row in the current sort order
* is kept, which is not deterministic
    if "$pin_merger_tie" == "1" {
        bys target_crd (mergeryear acquirercrds): keep if _n == 1
    }
    else {
        bys target_crd (mergeryear): keep if _n == 1 // keep first merger year associated with each target
    }
    tab mergeryear
    save data/output/mergers, replace

* Load firm characteristics from Form ADV (AUM in millions)
    use data/output/firm_adv_controls, clear
    replace dollar_aum = dollar_aum/1000000
    ren organizationcrd  crd
    gen year_aum = fiscal_year
    xtset crd year_aum

* Rolling average AUM growth and client growth
    gen aum_growth = ((dollar_aum - l.dollar_aum)/l.dollar_aum)*100
    gen client_growth = ((number_clients - l.number_clients)/l.number_clients)*100
    rangestat (mean) aum_growth client_growth , ///
              interval(year_aum -2 0) by(crd)

* Keep target firms and attach their merger
    ren crd target_crd
    merge m:1 target_crd using data/output/mergers
    keep if _m ==3
    drop _m
    ren acquirercrds acquirer_crd
    ren mergeryear acquired_year
    keep target_crd year_aum  ///
         dollar_aum broker_dealer_dummy number_clients adviser_age acquired_year ///
         aum_growth_mean client_growth_mean acquirer_crd fiscal_year

* Keep the first year before the acquisition
    gen event_time =  fiscal_year - acquired_year
    keep if event_time ==-1
    replace aum_growth_mean = 0 if aum_growth_mean ==.
    replace client_growth_mean = 0 if client_growth_mean ==.
    save data/output/target_stats, replace

* Add employee information to targets
    use data/output/firm_year_panel, clear
    ren crd_number target_crd
    gen acquired_year = year +1
    merge 1:1 target_crd acquired_year using data/output/target_stats, keep(3) nogen

* Construct the misconduct measures (percent of employees)
    gen fraction_bad_ever = (any_disclosureall/employees)*100
    gen fraction_bad_e_ever = (egan_disclosureall/employees)*100
    gen fraction_bad_a = (any_intensity_three/employees)*100
    gen fraction_bad_e = (egan_intensity_three/employees)*100
    gen fraction_bad_a_flow = (any_intensity_flow/employees)*100
    gen fraction_bad_e_flow = (egan_intensity_flow/employees)*100

* Merge the measures onto the target characteristics and save
    keep target_crd acquired_year employees fraction_bad_ever fraction_bad_e_ever fraction_bad_a fraction_bad_e fraction_bad_a_flow fraction_bad_e_flow
    duplicates drop
    merge 1:1 target_crd acquired_year using data/output/target_stats, keep(3) nogen
    save data/output/target_stats, replace
