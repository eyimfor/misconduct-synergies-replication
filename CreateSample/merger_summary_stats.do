********************************************************************************
* Estimation sample: mergers where both the target and the acquirer have Form
* ADV data in the year before the merger (485 deals). Writes merger_sample.dta,
* used from Table I on.
********************************************************************************

clear

* Keep merger pairs with summary statistics for both firms
    use data/output/target_stats, clear
    keep target_crd acquirer_crd acquired_year
    merge 1:1 target_crd acquirer_crd acquired_year using  data/output/acquirer_stats
    keep if _m ==3
    drop _m
    keep target_crd acquirer_crd acquired_year
    duplicates drop
    save data/output/both, replace

* Merger sample: restrict the merger list to those pairs
    use data/output/mergers, clear
    ren (acquirercrds mergeryear) (acquirer_crd acquired_year)
    merge 1:1 target_crd acquirer_crd acquired_year using data/output/both
    keep if _m ==3
    drop _m
    ren (acquirer_crd acquired_year) (acquirercrds mergeryear)
    save data/output/merger_sample, replace
