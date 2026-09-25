********************************************************************************
* Builds the restricted samples behind Appendix Table A.7 (broker-qualified
* advisers). Each adviser gets one status in the year before the merger (t-1),
* held fixed over the event window; the disclosure numerator and employee
* denominator are rebuilt from the individual-level panels restricted by it.
********************************************************************************
do "_settings.do"
cap log close
log using "$LOGS/03_build_status_robustness.log", replace text
di as text _n "Stata: " c(stata_version) " " c(edition_real) " born " c(born_date) " cores " c(processors)

* Status evidence, one row per id x b_crd_number:
*   Registration ("reg"): BD-representative vs IAR registration spells, from the
*     BrokerCheck/IAPD JSON nodes currentEmployments / previousEmployments (BD
*     scope) and currentIAEmployments / previousIAEmployments (IA scope),
*     scrapes 2020/2022/2024.
*   Exams ("exam"): cumulative exam qualifications at t-1 from
*     exam_qualifications.dta. Appendix Table A.7 reports this basis.
* Inputs are read only; everything is written to $DATA / $WD.


********************************************************************************
* Step 0. Person-event universe of the two individual-level panels
********************************************************************************

* Collapse each panel to one row per person-event, flagging presence at t-1
    foreach side in real cf {
        if "`side'" == "real" local f event_panel_real
        else local f event_panel_pseudo
        use id b_crd_number acquired_year year using "$SRC/output_robust/`f'", clear
        gen at_pair_t1 = (year == acquired_year - 1)
        collapse (max) at_pair_t1 (min) first_year = year (max) last_year = year, by(id b_crd_number acquired_year)
        isid id b_crd_number
        gen side = "`side'"
        save "$DATA/person_events_`side'", replace
    }

* List the distinct persons across both panels
    use "$DATA/person_events_real", clear
    append using "$DATA/person_events_cf"
    keep b_crd_number
    duplicates drop
    save "$DATA/panel_person_ids", replace
    count


********************************************************************************
* Step 1. Registration-scope spells (BD vs IA) from the raw scrape files
********************************************************************************

* Program: import one scrape file and keep the spells of panel persons
    cap program drop import_scope_file
    program define import_scope_file
        syntax , file(string) type(string) scope(string) scrapeyear(int)

    * Import the file; current registrations have no end date
        import delimited using "$RAW/`file'.csv", varnames(1) colrange(1:6) stringcols(_all) encoding("latin1") bindquote(loose) clear
        if "`type'" == "previous" {
            keep individualid firmid registrationbegindate registrationenddate
        }
        else {
            keep individualid firmid registrationbegindate
            gen registrationenddate = ""
        }

    * Keep panel persons only
        destring individualid firmid, replace force
        drop if individualid == . | firmid == .
        ren individualid b_crd_number
        merge m:1 b_crd_number using "$DATA/panel_person_ids", keep(3) nogen

    * Parse begin and end dates (MDY, falling back to YMD)
        gen begin_date = date(registrationbegindate, "MDY")
        replace begin_date = date(registrationbegindate, "YMD") if begin_date == .
        gen end_date = date(registrationenddate, "MDY")
        replace end_date = date(registrationenddate, "YMD") if end_date == . & registrationenddate != ""
        gen begin_year = year(begin_date)
        gen end_year = year(end_date)

    * Open (current) registrations are active through the scrape year
        gen open_spell = (registrationenddate == "")
        replace end_year = `scrapeyear' if open_spell

    * Tag scope and source, and keep spells with a begin year
        gen scope = "`scope'"
        gen source = "`file'"
        gen scrape_year = `scrapeyear'
        keep b_crd_number firmid begin_year end_year open_spell scope source scrape_year
        drop if begin_year == .
        qui count
        di as text "`file': `r(N)' spells kept for panel persons"
    end

* Stack the BD and IA files of the 2020, 2022 and 2024 scrapes
    tempfile spells
    local first = 1
    foreach yr in 2020 2022 2024 {
        foreach spec in "previous_employmentdata`yr' previous BD" "previousia_employmentdata`yr' previous IA" ///
                        "currentemploymentdata`yr' current BD" "currentia_employmentdata`yr' current IA" {
            tokenize `spec'
            import_scope_file, file(`1') type(`2') scope(`3') scrapeyear(`yr')
            if `first' == 0 append using `spells'
            save `spells', replace
            local first = 0
        }
    }

* Append the supplementary 2024 scrape files (missing2024)
    foreach spec in "previous_employmentdatamissing2024 previous BD" "previousia_employmentdatamissing2024 previous IA" ///
                    "currentemploymentdatamissing2024 current BD" "currentia_employmentdatamissing2024 current IA" {
        tokenize `spec'
        import_scope_file, file(`1') type(`2') scope(`3') scrapeyear(2024)
        append using `spells'
        save `spells', replace
    }

* One row per person x firm x scope x begin/end year (spells repeated across scrapes collapse to one)
    use `spells', clear
    collapse (max) open_spell (min) scrape_year, by(b_crd_number firmid scope begin_year end_year)
    tab scope
    save "$DATA/registration_spells", replace


********************************************************************************
* Step 2. Status at t-1, one row per id x b_crd_number (separately by side)
********************************************************************************

* Exam flags restricted to panel persons (exam_qualifications.dta: one row per
* person-year, cumulative flags)
    use "$SRC/output/exam_qualifications", clear
    merge m:1 b_crd_number using "$DATA/panel_person_ids", keep(3) nogen
    isid b_crd_number year
    keep b_crd_number year generalsecrep_m investmentcompanyprep_m series65_m series66_m securityessentialsexam_m ///
         securitiesagentstatelaw_m series79_m series82_m investmentadviserexam_m otherquals
    ren year year_t1
    save "$DATA/exams_panel_persons", replace

* Classify each person-event by registration scope and by exams at t-1
    foreach side in real cf {
        use "$DATA/person_events_`side'", clear
        gen year_t1 = acquired_year - 1

    * Registration scope at t-1 (anywhere in the industry)
        joinby b_crd_number using "$DATA/registration_spells", unmatched(master)
        gen covers = (begin_year <= year_t1 & end_year >= year_t1) & _merge == 3
        gen bd_cov = covers & scope == "BD"
        gen ia_cov = covers & scope == "IA"
        gen has_any_spell = (_merge == 3)
        collapse (max) bd_t1 = bd_cov ia_t1 = ia_cov has_any_spell at_pair_t1 first_year last_year, ///
                 by(side id b_crd_number acquired_year year_t1)
        isid id b_crd_number

    * Registered anywhere at t-1 according to the employment panel itself:
    * adviser_year is the adviser-year panel built from the employment extract
        ren year_t1 year
        merge m:1 b_crd_number year using "$SRC/output/adviser_year", keep(1 3)
        gen in_industry_t1 = (_merge == 3)
        drop _merge
        ren year year_t1

    * Exam qualifications at t-1
        merge m:1 b_crd_number year_t1 using "$DATA/exams_panel_persons", keep(1 3)
        gen has_exam_record_t1 = (_merge == 3)
        drop _merge

    * Registration-scope categories
        gen reg_status = 0
        replace reg_status = 1 if bd_t1 == 1 & ia_t1 == 0
        replace reg_status = 2 if bd_t1 == 0 & ia_t1 == 1
        replace reg_status = 3 if bd_t1 == 1 & ia_t1 == 1
        la def reg_status 0 "Unclassified / no active registration at t-1" 1 "Broker (BD rep) only" 2 "IAR only" 3 "Dual BD rep + IAR", replace
        la val reg_status reg_status
        gen reg_anybroker = inlist(reg_status, 1, 3)

    * Exam-qualification categories (SIE alone is not broker evidence)
        gen broker_q = (generalsecrep_m == 1 | investmentcompanyprep_m == 1)
        gen iar_q = (series65_m == 1 | (series66_m == 1 & generalsecrep_m == 1))
        gen exam_status = 0
        replace exam_status = 1 if broker_q == 1 & iar_q == 0
        replace exam_status = 2 if broker_q == 0 & iar_q == 1
        replace exam_status = 3 if broker_q == 1 & iar_q == 1
        la def exam_status 0 "Unclassified / no qualifying exam by t-1" 1 "Broker-qualified only (S6/S7)" 2 "IAR-qualified only (S65 or S66+S7)" 3 "Dual qualified", replace
        la val exam_status exam_status
        gen exam_anybroker = inlist(exam_status, 1, 3)

    * Check one status per person-event and a classification year strictly pre-merger
        isid id b_crd_number
        assert year_t1 < acquired_year
        assert inlist(reg_status, 0, 1, 2, 3) & inlist(exam_status, 0, 1, 2, 3)
        assert !missing(reg_status) & !missing(exam_status)
        save "$DATA/status_t1_`side'", replace

    * Tabulate the t-1 status distribution
        di as text _n "===== `side' panel: t-1 status distribution (person-events)"
        tab reg_status
        tab exam_status
        tab reg_status exam_status
        tab in_industry_t1 reg_status, row
        tab at_pair_t1 reg_status, row
        tab in_industry_t1 has_any_spell, row
    }

* Status distribution tables (person-events and person-year rows)
    tempname D
    postfile `D' str6 side str6 basis str12 unit str10 window int status str60 status_label double n share using "$DATA/status_distribution.dta", replace
    foreach side in real cf {
        foreach basis in reg exam {
        * Person-events by status
            use "$DATA/status_t1_`side'", clear
            qui count
            local tot = r(N)
            forvalues s = 0/3 {
                qui count if `basis'_status == `s'
                local lab : label `basis'_status `s'
                post `D' ("`side'") ("`basis'") ("person-event") ("all") (`s') ("`lab'") (r(N)) (r(N)/`tot')
            }

        * Person-year rows in the -3..+3 window, by pre/post
            if "`side'" == "real" local f event_panel_real
            else local f event_panel_pseudo
            use id b_crd_number acquired_year year using "$SRC/output_robust/`f'", clear
            gen event_time = year - acquired_year
            do "$PKG/_helpers/restrict_event_time.do"
            merge m:1 id b_crd_number using "$DATA/status_t1_`side'", keep(3) nogen keepusing(`basis'_status)
            gen window = cond(event_time < 0, "pre", "post")
            foreach w in pre post {
                qui count if window == "`w'"
                local tw = r(N)
                forvalues s = 0/3 {
                    qui count if window == "`w'" & `basis'_status == `s'
                    local lab : label `basis'_status `s'
                    post `D' ("`side'") ("`basis'") ("person-year") ("`w'") (`s') ("`lab'") (r(N)) (r(N)/`tw')
                }
            }
        }
    }
    postclose `D'

* Export and list the distribution
    use "$DATA/status_distribution.dta", clear
    export delimited using "$OUT/status_distribution.csv", replace
    list, noobs sepby(side basis unit)


********************************************************************************
* Step 3. Restricted aggregation: numerator and denominator from the same rows
********************************************************************************

* Program: aggregate the individual-level panel (with status merged in) to
* id x year cells for the subsets full, anybroker, brokeronly, iaronly, dual
    cap program drop aggregate_restricted
    program define aggregate_restricted
        syntax , basis(string) saving(string)

    * Subset indicators and per-subset disclosure and person counts
        gen k_full = 1
        gen k_anybroker  = inlist(`basis'_status, 1, 3)
        gen k_brokeronly = (`basis'_status == 1)
        gen k_iaronly    = (`basis'_status == 2)
        gen k_dual       = (`basis'_status == 3)
        egen person_tag = tag(id year b_crd_number)
        foreach s in full anybroker brokeronly iaronly dual {
            gen n_any_`s'  = any_intensity_sum  * k_`s'
            gen n_egan_`s' = egan_intensity_sum * k_`s'
            gen p_`s'  = person_tag * k_`s'
            gen pa_`s' = person_tag * k_`s' * (any_intensity_sum  > 0)
            gen pe_`s' = person_tag * k_`s' * (egan_intensity_sum > 0)
        }

    * Sum to id x year cells within the event window
        collapse (sum) k_full k_anybroker k_brokeronly k_iaronly k_dual ///
                       n_any_full n_any_anybroker n_any_brokeronly n_any_iaronly n_any_dual ///
                       n_egan_full n_egan_anybroker n_egan_brokeronly n_egan_iaronly n_egan_dual ///
                       p_full p_anybroker p_brokeronly p_iaronly p_dual ///
                       pa_full pa_anybroker pa_brokeronly pa_iaronly pa_dual ///
                       pe_full pe_anybroker pe_brokeronly pe_iaronly pe_dual, by(id year acquired_year)
        gen event_time = year - acquired_year
        do "$PKG/_helpers/restrict_event_time.do"
        gen post_merger = (event_time >= 0)

    * Rates: undefined (missing) when the restricted denominator is zero
        foreach s in full anybroker brokeronly iaronly dual {
            ren k_`s' employees_`s'
            ren p_`s' persons_`s'
            if "`s'" == "full" {
                gen any_misconduct_full  = n_any_full  / employees_full * 100
                gen egan_misconduct_full = n_egan_full / employees_full * 100
            }
            else {
                gen any_misconduct_`s'  = n_any_`s'  / employees_`s' * 100 if employees_`s' > 0
                gen egan_misconduct_`s' = n_egan_`s' / employees_`s' * 100 if employees_`s' > 0
            }

        * Validation: person-share numerators never exceed the person denominator,
        * rates are non-negative, restricted denominators never exceed the full ones
            assert pa_`s' <= persons_`s' & pe_`s' <= persons_`s'
            assert any_misconduct_`s' >= 0 | any_misconduct_`s' == .
            assert egan_misconduct_`s' >= 0 | egan_misconduct_`s' == .
            assert employees_`s' <= employees_full
            ren pa_`s' persons_pos_any_`s'
            ren pe_`s' persons_pos_egan_`s'
        }
        isid id year
        save "`saving'", replace
    end

* Build the restricted cells for each basis and side
    foreach basis in reg exam {
        foreach side in real cf {
            if "`side'" == "real" local f event_panel_real
            else local f event_panel_pseudo
            use id b_crd_number crd acquired_year year any_intensity_sum egan_intensity_sum using "$SRC/output_robust/`f'", clear
            merge m:1 id b_crd_number using "$DATA/status_t1_`side'", keep(1 3) keepusing(`basis'_status)
            assert _merge == 3
            drop _merge
            aggregate_restricted, basis(`basis') saving("$DATA/cells_`basis'_`side'")
        }
    }

* The full-sample cells must reproduce exactly the cells built by 02_rebuild_baseline_outcomes.do
    foreach side in real cf {
        if "`side'" == "real" local chk postmergercombinedfirm_rebuilt
        else local chk postmergercombinedfirmcf_rebuilt
        use "$DATA/cells_reg_`side'", clear
        merge 1:1 id year using "$DATA/`chk'", assert(3) nogen keepusing(employees any_misconduct egan_misconduct)
        assert employees == employees_full
        assert abs(any_misconduct - any_misconduct_full) < 1e-8
        assert abs(egan_misconduct - egan_misconduct_full) < 1e-8
        di as text "`side': full-sample cells identical to the step 02 rebuild (employees, any, egan)"
    }


********************************************************************************
* Step 4. Estimation samples per subset (same assembly logic as the baseline)
********************************************************************************

* Program: assemble the estimation sample for one basis and subset
    cap program drop assemble_subset
    program define assemble_subset
        syntax , basis(string) subset(string) saving(string)
        local s `subset'

    * Pseudo pairs: load pairs and merge the restricted counterfactual cells
        do "$PKG/_rules/merger_window.do" acquired_year load "$SRC/output/merger_pairs_long" "" "count == 1|count==2"
        reshape wide crd, i(id acquired_year) j(count)
        ren (crd1 crd2) (target_crd acquirer_crd)
        merge 1:m id acquired_year using "$DATA/cells_`basis'_cf"
        keep if _m ==3
        drop _m

    * Pseudo pairs: use the subset's outcomes and drop cells with an undefined rate
        keep id acquired_year target_crd acquirer_crd year event_time post_merger employees_full persons_full ///
             employees_`s' persons_`s' any_misconduct_`s' egan_misconduct_`s'
        gen any_misconduct = any_misconduct_`s'
        gen egan_misconduct = egan_misconduct_`s'
        gen employees_restricted = employees_`s'
        gen persons_restricted = persons_`s'
        drop any_misconduct_`s' egan_misconduct_`s'
        if "`s'" != "full" drop employees_`s' persons_`s'
        drop if any_misconduct == .   // undefined rate: no qualifying employee in the cell

    * Pseudo pairs: deduplicate and merge the combined-firm controls
        do "$PKG/_rules/dedup_key.do" select "id acquired_year event_time" "egan_misconduct any_misconduct" _N
        ren year year_aum
        duplicates drop
        merge m:1 event_time acquired_year target_crd acquirer_crd using "$DATA/combined_stats_pp_pseudo_ctrl"
        keep if _m ==3
        drop _m
        tempfile fake
        save `fake'

    * Real pairs: load pairs and merge the restricted real cells
        do "$PKG/_rules/merger_window.do" acquired_year load "$SRC/output/merger_pairs_long" "" "count == 0|count==3"
        reshape wide crd, i(id acquired_year) j(count)
        ren (crd0 crd3) (real_target real_acquirer)
        merge 1:m id acquired_year using "$DATA/cells_`basis'_real"
        keep if _m ==3
        drop _m

    * Real pairs: use the subset's outcomes and drop cells with an undefined rate
        keep id acquired_year real_target real_acquirer year event_time post_merger employees_full persons_full ///
             employees_`s' persons_`s' any_misconduct_`s' egan_misconduct_`s'
        gen any_misconduct = any_misconduct_`s'
        gen egan_misconduct = egan_misconduct_`s'
        gen employees_restricted = employees_`s'
        gen persons_restricted = persons_`s'
        drop any_misconduct_`s' egan_misconduct_`s'
        if "`s'" != "full" drop employees_`s' persons_`s'
        drop if any_misconduct == .

    * Real pairs: deduplicate and merge the combined-firm controls
        do "$PKG/_rules/dedup_key.do" select "id acquired_year event_time" "egan_misconduct any_misconduct" _N
        ren year year_aum
        do "$PKG/_rules/event_panel.do" merge 1:1 "event_time acquired_year real_target real_acquirer" "$DATA/combined_stats_pp_real_ctrl"
        keep if _m ==3
        drop _m
        ren (real_target real_acquirer) (target_crd acquirer_crd)
        tempfile real
        save `real'

    * Stack pseudo and real pairs
        use `fake', clear
        gen treated = 0
        append using `real'
        replace treated = 1 if treated == .
        ren (any_misconduct egan_misconduct) (fraction_bad_a_flow fraction_bad_e_flow)
        egen cohort = group(id)
        gen post = (event_time >=0)

    * Balance rules (identical to the baseline code)
        do "$PKG/_rules/thresholds.do" twins "id acquired_year event_time" treated
        drop obs
        bys id: egen min_event = min(event_time)
        bys id: egen max_event = max(event_time)
        do "$PKG/_rules/event_panel.do" presence
        do "$PKG/_helpers/restrict_event_time.do"
        gen interaction = treated*post

    * Controls, with the full-firm headcount as in the baseline (employees = all person-firm rows)
        gen employees = employees_full
        gen ln_employees = ln(employees)
        gen ln_aum = ln(dollar_aumc)
        egen ln_employees_std = std(ln_employees)
        egen ln_aum_std = std(dollar_aumc)
        gen ln_age = ln(combined_agec)
        egen ln_age_z = std(ln_age)
        gen basis = "`basis'"
        gen subset = "`s'"

    * Winsorize, validate and save
        do "$PKG/_rules/winsorize_last.do" ix_final "fraction_bad_a_flow fraction_bad_e_flow combined_aumg combined_clg"
        isid id treated event_time
        assert fraction_bad_a_flow >= 0 & fraction_bad_e_flow >= 0
        assert employees_restricted >= 1 & employees_restricted <= employees_full
        save "`saving'", replace
    end

* Build the estimation sample for each basis and subset
    foreach basis in reg exam {
        foreach s in full anybroker brokeronly iaronly dual {
            assemble_subset, basis(`basis') subset(`s') saving("$DATA/est_`basis'_`s'")
            use "$DATA/est_`basis'_`s'", clear
            di as text "basis=`basis' subset=`s': N = " _N
        }
    }

* The full-sample estimation file must match the one built by 02_rebuild_baseline_outcomes.do
    foreach basis in reg exam {
        use "$DATA/est_`basis'_full", clear
        keep id treated event_time fraction_bad_a_flow fraction_bad_e_flow employees both_retailc ln_aum_std ln_age_z ln_employees_std cohort year_aum
        foreach v in fraction_bad_a_flow fraction_bad_e_flow employees both_retailc ln_aum_std ln_age_z ln_employees_std cohort year_aum {
            ren `v' `v'_s
        }
        merge 1:1 id treated event_time using "$DATA/adviser_event_panel_rebuilt", assert(3) nogen ///
              keepusing(fraction_bad_a_flow fraction_bad_e_flow employees both_retailc ln_aum_std ln_age_z ln_employees_std cohort year_aum)
        foreach v in fraction_bad_a_flow fraction_bad_e_flow employees both_retailc ln_aum_std ln_age_z ln_employees_std cohort year_aum {
            assert abs(`v' - `v'_s) < 1e-6
        }
        di as text "basis=`basis': full-sample estimation file identical to the step 02 rebuild in all regression inputs"
    }


********************************************************************************
* Step 5. Attrition diagnostics: cells and events lost relative to the full sample
********************************************************************************

* Record, for each restricted subset, the cells, rows and events lost
    tempname A
    postfile `A' str6 basis str12 subset str40 stat double value using "$DATA/attrition.dta", replace
    foreach basis in reg exam {
        use "$DATA/est_`basis'_full", clear
        keep id treated event_time
        tempfile fullkeys
        save `fullkeys'
        foreach s in anybroker brokeronly iaronly dual {
        * Cells of the full estimation sample with zero qualifying employees
            use "$DATA/cells_`basis'_cf", clear
            gen treated = 0
            append using "$DATA/cells_`basis'_real"
            replace treated = 1 if treated == .
            keep id treated event_time employees_`s' employees_full
            merge 1:1 id treated event_time using `fullkeys', keep(3) nogen
            qui count
            local ncells_full = r(N)
            qui count if employees_`s' == 0
            local nzero = r(N)
            post `A' ("`basis'") ("`s'") ("full_sample_rows") (`ncells_full')
            post `A' ("`basis'") ("`s'") ("rows_with_zero_restricted_denominator") (`nzero')

        * Cohorts with any zero-denominator cell
            bys id: egen anyzero = max(employees_`s' == 0)
            preserve
                keep if anyzero
                keep id
                duplicates drop
                qui count
                local ids_anyzero = r(N)
            restore
            post `A' ("`basis'") ("`s'") ("cohorts_with_any_zero_denominator_cell") (`ids_anyzero')

        * Rows actually lost after re-applying the balance rules
            use "$DATA/est_`basis'_`s'", clear
            keep id treated event_time
            merge 1:1 id treated event_time using `fullkeys'
            qui count if _merge == 2
            post `A' ("`basis'") ("`s'") ("rows_lost_vs_full_sample") (r(N))
            qui count if _merge == 1
            post `A' ("`basis'") ("`s'") ("rows_added_vs_full_sample") (r(N))
            qui count if _merge == 3
            post `A' ("`basis'") ("`s'") ("rows_retained") (r(N))

        * Real events lost
            preserve
                keep if treated == 1
                keep id _merge
                bys id: egen kept = max(_merge == 3)
                keep id kept
                duplicates drop
                qui count
                local n_real_full = r(N)
                qui count if kept == 0
                post `A' ("`basis'") ("`s'") ("real_events_lost") (r(N))
                post `A' ("`basis'") ("`s'") ("real_events_full_sample") (`n_real_full')
            restore

        * Pseudo pairs lost
            preserve
                keep if treated == 0
                keep id _merge
                bys id: egen kept = max(_merge == 3)
                keep id kept
                duplicates drop
                qui count if kept == 0
                post `A' ("`basis'") ("`s'") ("pseudo_pairs_lost") (r(N))
            restore
        }
    }
    postclose `A'

* List the attrition diagnostics
    use "$DATA/attrition.dta", clear
    list, noobs sepby(basis subset)

log close
