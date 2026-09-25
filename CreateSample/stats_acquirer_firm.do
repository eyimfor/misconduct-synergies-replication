********************************************************************************
* Builds acquirer_stats: acquirer characteristics in the year before the merger,
* used by merger_summary_stats.do and in Table II.
********************************************************************************
clear

* Restrict to mergers in the sample period
    use data/output/mergers2021and2023, clear
    duplicates drop
    do "$PKG/_helpers/restrict_merger_year.do"

* Keep one merger per target. When a target has two acquirers in the same
* year, $pin_merger_tie = 1 keeps the lowest acquirer CRD (deterministic, as in
* stats_target_firm.do); 0 keeps the first row in the data's current order,
* which an unstable sort does not fix
    if "$pin_merger_tie" == "1" {
        bys target_crd (mergeryear acquirercrds): keep if _n == 1
    }
    else {
        bys target_crd (mergeryear): keep if _n == 1 // keep first merger year associated with each target
    }
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

* Attach each acquirer's mergers
    ren crd acquirercrds
    joinby acquirercrds using data/output/mergers
    ren acquirercrds acquirerscrd
    ren mergeryear acquired_year
    keep acquirerscrd year_aum  ///
         dollar_aum broker_dealer_dummy number_clients adviser_age acquired_year ///
         aum_growth_mean client_growth_mean retail_clients aum_growth client_growth target_crd fiscal_year
    ren acquirerscrd acquirer_crd

* Keep the first year before the acquisition
    gen event_time =  fiscal_year - acquired_year
    keep if event_time ==-1
    replace aum_growth_mean = 0 if aum_growth_mean ==.
    replace client_growth_mean = 0 if client_growth_mean ==.
    save data/output/acquirer_stats, replace

* Add employee information to acquirers
    use data/output/firm_year_panel, clear
    ren crd_number acquirer_crd
    gen acquired_year = year +1
    merge 1:m acquirer_crd acquired_year using data/output/acquirer_stats
    keep if _m ==3
    drop _m

* Construct the misconduct measures (percent of employees)
    gen fraction_bad_ever = (any_disclosureall/employees)*100
    gen fraction_bad_e_ever = (egan_disclosureall/employees)*100
    gen fraction_bad_a = (any_intensity_three/employees)*100
    gen fraction_bad_e = (egan_intensity_three/employees)*100
    gen fraction_bad_a_flow = (any_intensity_flow/employees)*100
    gen fraction_bad_e_flow = (egan_intensity_flow/employees)*100

* Merge the measures onto the acquirer characteristics and save
    keep acquirer_crd acquired_year employees fraction_bad_ever fraction_bad_e_ever ///
         fraction_bad_a fraction_bad_e fraction_bad_a_flow fraction_bad_e_flow
    duplicates drop
    merge 1:m acquirer_crd acquired_year using data/output/acquirer_stats
    keep if _m ==3
    drop _m
    save data/output/acquirer_stats, replace
