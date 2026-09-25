********************************************************************************
* One merger event list per exhibit family. Modes: sample; never_merged. Each
* call leaves its list in memory.
********************************************************************************
args operation

* sample: the merger sample used by the target and acquirer regressions
    if "`operation'" == "sample" {
        use data/output/merger_sample, clear
        exit
    }

* never_merged: every firm that appears in any merger, in either role and any
* year; pseudo-merged matches are selected among candidates outside this list
    if "`operation'" == "never_merged" {
        * Stack the merger pairs from both merger lists
        use data/output/merger_pairs_raw, clear
        keep target_crd acquirercrds
        append using ../2023/data/output/mergers2021and2023
        keep target_crd acquirercrds

        * Save the targets, then append the acquirers as one list of unique crd_number
        tempfile all_merging_pairs all_merging_targets
        save `all_merging_pairs'
        keep target_crd
        ren target_crd crd_number
        save `all_merging_targets'
        use `all_merging_pairs', clear
        keep acquirercrds
        ren acquirercrds crd_number
        append using `all_merging_targets'
        drop if missing(crd_number)
        duplicates drop
        exit
    }

* Any other mode is an error
    display as error "event_list: unknown operation `operation'"
    exit 198
