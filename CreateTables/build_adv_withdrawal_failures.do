********************************************************************************
* Builds failed_businesses_sec.dta: firms that withdrew their Form ADV
* registration for a closure reason, with the withdrawal date (died),
* excluding merger targets. Used by Table XII, Panel B.
********************************************************************************
clear

* Import the Form ADV-W withdrawals
    import delimited "$PKG/upstream_inputs/all_withdrawals.csv", varnames(1) clear
    replace reasonsforwithdrawal = lower(reasonsforwithdrawal)

* Flag withdrawals whose stated reason is a closure
    gen closure_reason = (reasonsforwithdrawal == "no longer in business or closing business" | ///
                          reasonsforwithdrawal == "no longer conducting advisory activities"| ///
                          reasonsforwithdrawal == "ceased conducting advisory business" | ///
                          reasonsforwithdrawal == "termination of business" | ///
                          reasonsforwithdrawal == "going out of business" | ///
                          reasonsforwithdrawal == "closed business")
    keep crdnumber dateceased fulllegalname reasonsforwithdrawal closure_reason
    duplicates drop

* Keep the latest cease date for each CRD
    do "$PKG/_rules/filing_pins.do" failure_last
    format died %td
    drop if died == .
    drop dateceased
    ren crdnumber organizationcrd
    duplicates drop
    bys organizationcrd (died): keep if _n ==1
    save data/output/failed_businesses_sec, replace

* Keep closures and exclude firms that appear as merger targets
    use data/output/failed_businesses_sec, clear
    keep if closure_reason
    drop closure_reason
    ren organizationcrd target_crd
    merge 1:m target_crd using data/output/merger_pairs_raw, keepusing(target_crd)
    keep if _m==1
    drop _m
    ren target_crd organizationcrd
    save data/output/failed_businesses_sec, replace
