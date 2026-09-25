********************************************************************************
* Entry point for the merger list: applies the sample window (mergers from January
* 2011 through December 2020) and the one-deal-per-target rule before any downstream
* event list is built. Used by every merger-dependent table and figure.
* Usage: prepare 0|1; load 0|1; check 0|1 (validation only).
********************************************************************************
args action known

* Accept only 0 or 1 for the ADV-filer restriction
    if !inlist("`known'", "0", "1") exit 198


********************************************************************************
* prepare: build the entry list from the hand-collected merger list
********************************************************************************

* Import the list and apply the window, earliest-deal and optional ADV-filer
* restrictions, which are in merger_window.do, dedup_key.do and target_crd_known.do
    if "`action'" == "prepare" {
        * Import the hand-collected list and check its keys
        import delimited using data/input/new_mergers_raw.csv, clear varnames(1) stringcols(5 6 7 8 9)
        rename acquirer_crd acquirercrds
        confirm numeric variable deal_id target_crd acquirercrds mergeryear
        assert !missing(deal_id, target_crd, acquirercrds, mergeryear)
        isid deal_id
        isid target_crd acquirercrds mergeryear
        display "IMPORTED_RAW_PAIRS = " _N

        * Save every target-acquirer pair in the hand-collected list, before the window and
        * earliest-deal restrictions. Used where a script needs "was this firm ever in a
        * merger", rather than the analysis sample: the failed-business exclusion and the
        * never-merged control pool.
        preserve
            keep target_crd acquirercrds
            duplicates drop
            save data/output/merger_pairs_raw.dta, replace
            display "RAW_PAIRS = " _N
        restore

        * Apply the sample window
        do "$PKG/_rules/merger_window.do" mergeryear filter
        display "WINDOW_ROWS = " _N

        * Keep one deal per target. Priority: earliest in-window year, then lowest acquirer CRD
        do "$PKG/_rules/dedup_key.do" select "target_crd" "mergeryear acquirercrds" 1
        display "EARLIEST_TARGET_ROWS = " _N

        * Apply the optional ADV-filer restriction, validate and save every column of the list
        do "$PKG/_rules/target_crd_known.do" `known'
        char _dta[target_known] "`known'"
        do "$PKG/_rules/merger_list.do" check `known'
        save data/input/new_mergers_entry.dta, replace
        exit
    }


********************************************************************************
* load: load the prepared entry list as the merger list
********************************************************************************

* Check that the prepared list used the same restriction, validate and save it
    if "`action'" == "load" {
        use data/input/new_mergers_entry.dta, clear
        local prepared_known : char _dta[target_known]
        if "`prepared_known'" != "`known'" exit 459
        do "$PKG/_rules/merger_list.do" check `known'
        save data/output/mergers2021and2023, replace
        cf _all using data/input/new_mergers_entry.dta
        display "LOAD_EQUALS_PREPARED=1"
        display "LOADED_ROWS = " _N
        exit
    }


********************************************************************************
* check: validate the merger list in memory
********************************************************************************

* Check the window, one deal per target and missing keys
    if "`action'" == "check" {
        * Count mergers outside the sample window
        confirm numeric variable target_crd acquirercrds mergeryear
        count if !inrange(mergeryear, 2011, 2020)
        local outside = r(N)
        display "OUT_OF_WINDOW = " `outside'

        * Count targets with mergers in more than one year
        tempvar earliest latest target_tag
        bysort target_crd: egen `earliest' = min(mergeryear)
        bysort target_crd: egen `latest' = max(mergeryear)
        egen `target_tag' = tag(target_crd)
        count if `target_tag' & `earliest' != `latest'
        local multiple = r(N)
        display "TARGETS_MULTIPLE_YEARS = " `multiple'
        drop `earliest' `latest' `target_tag'

        * Report the list size and mergers per year
        display "ENTRY_TARGET_KNOWN = `known'"
        display "ENTRY_ROWS = " _N
        forvalues entry_year = 2011/2020 {
            quietly count if mergeryear == `entry_year'
            display "YEAR `entry_year' = " r(N)
        }

        * Require one in-window deal per target with no missing keys
        assert `outside' == 0
        assert `multiple' == 0
        isid target_crd
        assert !missing(target_crd, acquirercrds, mergeryear)
        exit
    }

* Any other action is an error
    exit 198
