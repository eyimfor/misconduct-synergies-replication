********************************************************************************
* Labor-market outcomes after a separation for Table A.8, built from the saved
* Table X panels. A separated adviser leaves the industry if never again
* registered with any advisory firm in the employment data, and joins a
* different firm if registered with another firm in a subsequent year.
********************************************************************************
* Each adviser is followed until the first separation. The file inherits the
* Table X adviser filter, windows and separation flags without refiltering.
* Modes: history; roster; sample target|acquirer; attach <history> <roster>.
args action first second


********************************************************************************
* history: first and last employment year for each adviser-employer pair
********************************************************************************
if "`action'" == "history" {

    * Load the adviser-firm-year panel and drop rows with a missing key
        use b_crd_number crd_number year using data/output/adviser_firm_year, clear
        scalar LABOR_history_rows = _N
        count if missing(b_crd_number, crd_number, year)
        scalar LABOR_invalid_history_rows = r(N)
        drop if missing(b_crd_number, crd_number, year)
        assert year == floor(year)

    * Record the observed year range
        summarize year, meanonly
        scalar LABOR_history_first_year = r(min)
        scalar LABOR_history_last_year = r(max)

    * Collapse to one row per adviser-employer pair
        collapse (min) labor_first_emp_year=year (max) labor_last_emp_year=year, by(b_crd_number crd_number)
        isid b_crd_number crd_number
        scalar LABOR_history_employer_keys = _N
        exit
}


********************************************************************************
* roster: the firms in each deal's firm unit (origin firm and deal partner)
********************************************************************************
if "`action'" == "roster" {

    * Load the deals; save targets with the acquirer as partner (role 1)
        use target_crd acquirer_crd acquired_year using data/output/temp_one2, clear
        assert !missing(target_crd, acquirer_crd, acquired_year)
        tempfile labor_events labor_target_partners labor_own_firms
        save `labor_events'
        gen byte labor_role = 1
        rename target_crd labor_origin_crd
        rename acquirer_crd crd_number
        save `labor_target_partners'

    * Build acquirers with the target as partner (role 2) and stack both
        use `labor_events', clear
        gen byte labor_role = 2
        rename acquirer_crd labor_origin_crd
        rename target_crd crd_number
        append using `labor_target_partners'

    * Add each origin firm as a member of its own unit
        preserve
            keep labor_role labor_origin_crd acquired_year
            gen long crd_number = labor_origin_crd
            save `labor_own_firms'
        restore
        append using `labor_own_firms'

    * Drop duplicates on the exact projected keys; no partner is selected over another
        do "$PKG/_rules/dedup_key.do" select "labor_role labor_origin_crd acquired_year crd_number" "" 1
        isid labor_role labor_origin_crd acquired_year crd_number
        gen byte labor_in_unit = 1
        exit
}


********************************************************************************
* sample: load the target or acquirer panel and check its structure
********************************************************************************
if "`action'" == "sample" {

    * Load the requested panel and set the role and origin firm
        if "`first'" == "target" {
            use data/output/regressionbrokerstarget, clear
            gen byte labor_role = 1
            gen long labor_origin_crd = target_crd
        }
        else if "`first'" == "acquirer" {
            use data/output/regressionbrokersacq, clear
            gen byte labor_role = 2
            gen long labor_origin_crd = acquirer_crd
        }
        else {
            display as error "labor_outcomes: sample must be target or acquirer"
            exit 198
        }

    * Check the keys, flags and windows inherited from the Table X panel
        gen long labor_source_row = _n
        isid b_crd_number labor_origin_crd acquired_year year
        assert !missing(b_crd_number, labor_origin_crd, acquired_year, year)
        assert inlist(separation, 0, 100)
        assert brokeroradviser == 1
        assert inlist(any_intensity_sum_z, 0, 1)
        assert !missing(any_intensity)
        assert any_intensity_sum_z == (any_intensity > 0)
        assert post_merger == (year >= acquired_year)
        assert event_time == year - acquired_year
        assert inrange(acquired_year, 2011, 2020)
        assert inrange(event_time, -3, 3)
        assert inrange(year, 2009, 2022)

    * Check that each adviser separates at most once, in the last observed year
        tempvar labor_separation_count
        bysort b_crd_number labor_origin_crd acquired_year (year): gen byte `labor_separation_count' = sum(separation == 100)
        assert `labor_separation_count' <= 1
        by b_crd_number labor_origin_crd acquired_year: assert _n == _N if separation == 100
        drop `labor_separation_count'
        sort labor_source_row
        exit
}


********************************************************************************
* attach: outcomes for each separation, merged back onto the sample
********************************************************************************
if "`action'" == "attach" {
    local labor_source_n = _N
    tempfile labor_outcomes

    * For each separation, flag later employment anywhere and outside the firm unit
        preserve
            keep if separation == 100
            keep labor_source_row b_crd_number labor_role labor_origin_crd acquired_year year post_merger
            if _N > 0 {
                joinby b_crd_number using "`first'", unmatched(master)
                assert _merge == 3
                drop _merge
                merge m:1 labor_role labor_origin_crd acquired_year crd_number using "`second'", keep(master match) nogen
                gen byte labor_future_any = (labor_last_emp_year > year & labor_last_emp_year < .)
                gen byte labor_future_other = labor_future_any & crd_number != labor_origin_crd & (post_merger == 0 | labor_in_unit != 1)
                collapse (max) labor_future_any labor_future_other labor_last_emp_year, by(labor_source_row)
                isid labor_source_row
            }
            else {
                keep labor_source_row
                gen byte labor_future_any = .
                gen byte labor_future_other = .
                gen int labor_last_emp_year = .
            }
            save `labor_outcomes'
        restore

    * Merge the flags back onto every sample row
        merge 1:1 labor_source_row using `labor_outcomes', assert(master match) nogen
        assert _N == `labor_source_n'
        assert !missing(labor_future_any, labor_future_other, labor_last_emp_year) if separation == 100
        assert missing(labor_future_any, labor_future_other) if separation == 0

    * Classify each separation into exactly one outcome
        gen byte labor_left_industry = (labor_future_any == 0) if separation == 100
        gen byte labor_join_different = labor_future_other if separation == 100
        gen byte labor_return_only = (labor_future_any == 1 & labor_future_other == 0) if separation == 100
        assert labor_left_industry + labor_join_different + labor_return_only == 1 if separation == 100

    * Years from the origin year to the last observed year
        gen int labor_observed_endpoint = scalar(LABOR_history_last_year)
        gen int labor_followup_years = labor_observed_endpoint - year
        assert labor_followup_years >= 0

    * Label the outcomes
        label variable labor_left_industry "No observed employer in any year after the origin year"
        label variable labor_join_different "Later employer outside the origin-year firm unit"
        label variable labor_return_only "Later employers confined to the origin-year firm unit"
        label variable labor_followup_years "Observed endpoint minus origin year (not guaranteed coverage)"
        sort labor_source_row
        exit
}

* Reject any other mode
display as error "labor_outcomes: unknown action `action'"
exit 198
