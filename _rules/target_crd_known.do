********************************************************************************
* Optional restriction that the target CRD appears among Form ADV filers
* (firm_adv_controls.dta, column organizationcrd). Applied by merger_list.do,
* so it reaches every merger-dependent table and figure; off in every exhibit.
********************************************************************************
* Usage: do "$PKG/_rules/target_crd_known.do" 0|1; leaves the retained pairs in memory
args known

* Validate the switch: 1 keeps only targets among Form ADV filers, 0 leaves the pairs unchanged
    if !inlist("`known'", "0", "1") exit 198
    global TARGET_CRD_KNOWN `known'
    confirm numeric variable target_crd

* Keep only targets whose CRD appears among Form ADV filers
    if ${TARGET_CRD_KNOWN} {
        preserve
            use organizationcrd using data/output/firm_adv_controls.dta, clear
            drop if missing(organizationcrd)
            duplicates drop
            rename organizationcrd target_crd
            isid target_crd
            tempfile adv_universe
            save `adv_universe'
        restore
        merge m:1 target_crd using `adv_universe', keep(3) nogen
    }

* Report the switch and the number of retained raw pairs
    display "TARGET_CRD_KNOWN = " ${TARGET_CRD_KNOWN}
    display "RETAINED_RAW_PAIRS = " _N
