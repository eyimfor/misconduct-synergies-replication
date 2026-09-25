********************************************************************************
* Builds target_acquirer_stats.dta: target and acquirer firm statistics for
* merger pairs with data on both sides, winsorized, for the comparison in
* Table II.
********************************************************************************
clear

* Keep only target and acquirer pairs with the requisite data
    use data/output/target_stats, clear
    keep target_crd acquirer_crd acquired_year
    merge 1:1 target_crd acquirer_crd acquired_year using  data/output/acquirer_stats
    keep if _m ==3
    drop _m
    keep target_crd acquirer_crd acquired_year
    duplicates drop
    save data/output/both, replace

* Filter the acquirer data to those pairs
    use data/output/acquirer_stats, clear
    merge 1:1 target_crd acquirer_crd acquired_year using data/output/both
    keep if _m ==3
    drop _m
    gen crd_n = acquirer_crd
    save data/output/acquirer_stats_b, replace

* Combine target and acquirer statistics to compare differences in means
    use data/output/target_stats, clear
    merge 1:1 target_crd acquirer_crd acquired_year using data/output/both
    keep if _m ==3
    drop _m
    gen crd_n = target_crd
    gen target = 1
    append using data/output/acquirer_stats_b
    replace target = 0 if target == .
    gen crd = _n
    keep year_aum crd employees fraction_bad_ever fraction_bad_e_ever fraction_bad_a fraction_bad_e fraction_bad_a_flow ///
         fraction_bad_e_flow  ///
         dollar_aum  number_clients ///
         aum_growth_mean client_growth_mean acquirer_crd target acquired_year crd_n

* Winsorize the statistics
    do "$PKG/_rules/winsorize_last.do" table2_final "fraction_bad_ever fraction_bad_e_ever fraction_bad_a fraction_bad_e fraction_bad_a_flow fraction_bad_e_flow aum_growth_mean client_growth_mean"

* Flip the indicator: target == 0 is the target firm and target == 1 the
* acquirer, the column order Table II prints (_8_summary_statistics.py,
* _9_port_stats_tables.py)
    replace target = abs(target -1)
    save data/output/target_acquirer_stats, replace
