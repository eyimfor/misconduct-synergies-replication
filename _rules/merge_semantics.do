********************************************************************************
* Merge semantics: which side governs membership, which side supplies
* attributes, and how records attach to an event.
* Used by Figures 1 and 6 and by the line-of-business appendix script.
********************************************************************************

gettoken operation 0 : 0

* adv_membership: the sample includes investment advisory firms that filed a
* Form ADV between 2009 and 2022 and have employee employment history
    if "`operation'" == "adv_membership" {
        * Finish the firm-panel attach
            drop if _m == 1
            drop _m

        * Build a same-fiscal/calendar-year ADV key file; the tempfile is
        * created, read and discarded within this call
            preserve
                use data/output/firm_adv_controls, clear
                keep organizationcrd fiscal_year dollar_aum
                ren (organizationcrd fiscal_year) (crd_number year)
                isid crd_number year
                tempfile adv_members
                save `adv_members'
            restore

        * Require a same-year ADV row
            merge 1:1 crd_number year using `adv_members'
            keep if _m == 3
            drop _m
            exit
    }

* project_gate_attribute: keep the caller's existing projection plus the AUM
* attribute the firm-year gate needs
    if "`operation'" == "project_gate_attribute" {
        keep `0' dollar_aum
        exit
    }

* combined_membership: Figure 6 computes both series over one fixed cohort,
* advisers employed at the target or the acquirer before the merger year,
* excluding advisers hired after the merger; the actual series counts cohort
* advisers registered with the combined firm in year t
    if "`operation'" == "combined_membership" {
        * Target and acquirer firms of each event; the same merger_pairs_long id
        * is used by the fixed-cohort builder
            use data/output/merger_pairs_long, clear
            keep if count == 0 | count == 3
            keep id crd
            duplicates drop
            ren crd crd_number

        * Attach the advisers registered with those firms in each year
            joinby crd_number using data/output/adviser_firm_year
            keep id b_crd_number year
            duplicates drop

        * Keep adviser-years in the fixed cohort panel
            merge 1:m id b_crd_number year using data/output/fig6_adviser_panel
            keep if _m == 3
            drop _m
            exit
    }

* combined_firm_cohort (Figure 6): one row per event and firm; a firm flagged
* as target in any row of the event is the target
    if "`operation'" == "combined_firm_cohort" {
        * Check the inputs and count rows, firms and events before collapsing
            keep id crd acquired_year target
            assert inlist(target, 0, 1)
            bys id crd (acquired_year): assert acquired_year == acquired_year[1]
            local roster_before = _N
            tempvar any_target roster_key roster_event
            egen byte `roster_key' = tag(id crd)
            quietly count if `roster_key'
            local firms_before = r(N)
            egen byte `roster_event' = tag(id)
            quietly count if `roster_event'
            local events_before = r(N)
            drop `roster_key' `roster_event'

        * Flag a firm as target if it is the target in any row of the event
            bys id crd: egen byte `any_target' = max(target)
            replace target = `any_target'
            drop `any_target'
            duplicates drop

        * Confirm no firm or event is lost
            isid id crd
            assert _N == `firms_before'
            egen byte `roster_event' = tag(id)
            quietly count if `roster_event'
            assert r(N) == `events_before'
            drop `roster_event'

        * Report the cohort counts
            display "COHORT_EVENT_UNION = " `events_before'
            display "COHORT_FIRM_UNION = " `firms_before'
            display "COHORT_ROSTER_BEFORE = " `roster_before'
            display "COHORT_ROSTER_AFTER = " _N
            exit
    }

* event_key_attach: attaches target_crd, acquirercrds and mergeryear from the
* merger list to each deal
    if "`operation'" == "event_key_attach" {
        * Read the arguments
            gettoken method 0 : 0
            gettoken key 0 : 0
            gettoken source 0 : 0
            gettoken cardinality 0 : 0
            if !inlist("`method'", "join", "merge") exit 198

        * Build the event key file from the merger list
            preserve
                use `source', clear
                local input_rows = _N
                keep target_crd acquirercrds mergeryear
                assert _N == `input_rows'
                isid target_crd acquirercrds mergeryear
                tempfile name_event_keys
                save `name_event_keys'
            restore

        * Attach the keys by joinby or merge
            if "`method'" == "join" {
                joinby `key' using `name_event_keys'
            }
            else {
                merge `cardinality' `key' using `name_event_keys'
            }
            display "NAME_KEY_INPUT_ROWS = " `input_rows'
            exit
    }

* Any other operation is an error
    display as error "merge_semantics: unknown operation `operation'"
    exit 198
