********************************************************************************
* Rebuilds the Table IX estimation sample from the individual-level real and
* pseudo adviser panels, checks it against the pipeline's pair-year files and
* adviser_event_panel.dta, and re-estimates Table IX on the rebuilt sample.
* Outputs are written to $DATA and $OUT.
********************************************************************************
do "_settings.do"
cap log close
log using "$LOGS/02_rebuild_baseline_outcomes.log", replace text
di as text _n "Stata: " c(stata_version) " " c(edition_real) " born " c(born_date) " cores " c(processors)


********************************************************************************
* Part A. Aggregate the individual-level panels to pair-year cells
********************************************************************************

* Program: aggregate person-firm rows to id-year cells with the same rule as
* post_merger_misconduct_real.do and post_merger_misconduct_pseudo.do
    cap program drop aggregate_cells
    program define aggregate_cells
        * Count person-firm rows per id-year cell (employees) and sum the rolling
        * three-year disclosure counts over those rows
            syntax , saving(string)
            bys id year: gen employees = _N
            bys id year: egen all_intensity_flow1 = sum(any_intensity)
            bys id year: egen egan_intensity_flow1 = sum(egan_intensity)
            bys id year: egen all_intensity_flow = sum(any_intensity_sum)
            bys id year: egen egan_intensity_flow = sum(egan_intensity_sum)
            bys id year: egen all_intensity_flowN = sum(cumulative_disclosures)
            bys id year: egen egan_intensity_flowN = sum(cumulative_disclosures_egan)

        * Express each count per 100 employees
            foreach x in all_intensity_flow1 egan_intensity_flow1 all_intensity_flow ///
                         egan_intensity_flow all_intensity_flowN egan_intensity_flowN {
                replace `x' = 0 if `x' == .
                replace `x' = ((`x')/employees)*100
            }

        * Keep one row per id-year and apply the event-time window
            gen event_time = year - acquired_year
            keep id year event_time all_intensity_flow1 egan_intensity_flow1 ///
                 all_intensity_flow egan_intensity_flow all_intensity_flowN egan_intensity_flowN employees acquired_year
            duplicates drop
            ren (all_intensity_flow egan_intensity_flow) (any_misconduct egan_misconduct)
            do "$PKG/_helpers/restrict_event_time.do"
            gen post_merger = (event_time >= 0)
            isid id year
            save "`saving'", replace
    end

* Program: cell-by-cell comparison of a rebuilt pair-year file with the pipeline's file
    cap program drop compare_cells
    program define compare_cells
        * Merge the two files and count matched and unmatched cells
            syntax , rebuilt(string) pipeline(string) label(string) handle(string)
            use "`rebuilt'", clear
            local n_rebuilt = _N
            merge 1:1 id year using "`pipeline'"
            qui count if _merge == 1
            local only_rebuilt = r(N)
            qui count if _merge == 2
            local only_pipeline = r(N)
            qui count if _merge == 3
            local matched = r(N)

        * For each variable, post the number of differing cells and the largest difference
            foreach v in employees any_misconduct egan_misconduct all_intensity_flow1 egan_intensity_flow1 all_intensity_flowN egan_intensity_flowN event_time acquired_year {
                cap confirm variable `v'
                if _rc continue
                preserve
                    keep if _merge == 3

                    * Compare against the pipeline file's copy of the variable
                    tempfile mine
                    keep id year `v'
                    ren `v' `v'_rebuilt
                    save `mine'
                    use "`pipeline'", clear
                    keep id year `v'
                    merge 1:1 id year using `mine', keep(3) nogen
                    gen __d = `v' - `v'_rebuilt
                    qui sum __d
                    local maxabs = max(abs(r(min)), abs(r(max)))
                    qui count if abs(__d) > 1e-6
                    local ndiff = r(N)
                    post `handle' ("`label'") ("`v'") (`n_rebuilt') (`matched') (`only_rebuilt') (`only_pipeline') (`ndiff') (`maxabs')
                restore
            }
    end

* Open the cell-comparison results file
    tempname CC
    postfile `CC' str30 file str30 variable long n_rebuilt matched only_rebuilt only_pipeline n_cells_diff double max_abs_diff using "$DATA/cell_comparison.dta", replace

* Real pairs: rebuild the cells and compare with the pipeline's file
    use "$SRC/output_robust/event_panel_real", clear
    di as text "output_robust/event_panel_real.dta file date: " c(filedate)
    describe, short
    duplicates report id b_crd_number year
    duplicates report id b_crd_number crd year
    aggregate_cells, saving("$DATA/postmergercombinedfirm_rebuilt.dta")
    compare_cells, rebuilt("$DATA/postmergercombinedfirm_rebuilt.dta") pipeline("$SRC/output_robust/postmergercombinedfirm.dta") label("real_output_robust") handle(`CC')

* Pseudo pairs: rebuild the cells and compare with the pipeline's file
    use "$SRC/output_robust/event_panel_pseudo", clear
    di as text "output_robust/event_panel_pseudo.dta file date: " c(filedate)
    describe, short
    duplicates report id b_crd_number year
    duplicates report id b_crd_number crd year
    aggregate_cells, saving("$DATA/postmergercombinedfirmcf_rebuilt.dta")
    compare_cells, rebuilt("$DATA/postmergercombinedfirmcf_rebuilt.dta") pipeline("$SRC/output_robust/postmergercombinedfirmcf.dta") label("pseudo_output_robust") handle(`CC')

* Close, list and export the cell comparison
    postclose `CC'
    use "$DATA/cell_comparison.dta", clear
    list, noobs
    export delimited using "$OUT/baseline_cell_comparison.csv", replace


********************************************************************************
* Part B. Combined-firm controls for the pseudo and real pairs, from the
* pipeline's combined_stats_pp_pseudo and combined_stats_pp_real files
********************************************************************************

* Pseudo-pair controls
    use "$SRC/output/combined_stats_pp_pseudo", clear
    keep acquired_year target_crd acquirer_crd year_aum event_time dollar_aumc number_clientsc both_retailc combined_agec combined_aumg combined_clg
    duplicates drop
    isid target_crd acquirer_crd acquired_year event_time
    save "$DATA/combined_stats_pp_pseudo_ctrl", replace

* Real-pair controls
    use "$SRC/output/combined_stats_pp_real", clear
    keep acquired_year target_crd acquirer_crd year_aum event_time dollar_aumc number_clientsc both_retailc combined_agec combined_aumg combined_clg
    duplicates drop
    rename (target_crd acquirer_crd) (real_target real_acquirer)
    isid real_target real_acquirer acquired_year event_time
    save "$DATA/combined_stats_pp_real_ctrl", replace


********************************************************************************
* Part C. Attach outcomes and build the estimation sample with the assembly
* rules of pseudo_real_merger_test.do
********************************************************************************

* Program: assemble the stacked pseudo/real estimation sample
    cap program drop assemble_panel
    program define assemble_panel
        * Parse options
            syntax , realfile(string) cffile(string) saving(string)
            local winsorlist fraction_bad_a_flow fraction_bad_e_flow combined_aumg combined_clg

        * Pseudo pairs: attach target and acquirer CRDs to the rebuilt cells
            do "$PKG/_rules/merger_window.do" acquired_year load "$SRC/output/merger_pairs_long" "" "count == 1|count==2"
            reshape wide crd, i(id acquired_year) j(count)
            ren (crd1 crd2) (target_crd acquirer_crd)
            merge 1:m id acquired_year using "`cffile'"
            keep if _m ==3
            drop _m

        * Pseudo pairs: one row per event time, then attach the controls
            do "$PKG/_rules/dedup_key.do" select "id acquired_year event_time" "egan_misconduct any_misconduct" _N
            ren year year_aum
            duplicates drop
            merge m:1 event_time acquired_year target_crd acquirer_crd using "$DATA/combined_stats_pp_pseudo_ctrl"
            keep if _m ==3
            drop _m
            tempfile fake
            save `fake'

        * Real pairs: attach target and acquirer CRDs to the rebuilt cells
            do "$PKG/_rules/merger_window.do" acquired_year load "$SRC/output/merger_pairs_long" "" "count == 0|count==3"
            reshape wide crd, i(id acquired_year) j(count)
            ren (crd0 crd3) (real_target real_acquirer)
            merge 1:m id acquired_year using "`realfile'"
            keep if _m ==3
            drop _m

        * Real pairs: one row per event time, then attach the controls
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

        * Apply the balance rules and the event-time window
            do "$PKG/_rules/thresholds.do" twins "id acquired_year event_time" treated
            drop obs
            bys id: egen min_event = min(event_time)
            bys id: egen max_event = max(event_time)
            do "$PKG/_rules/event_panel.do" presence
            do "$PKG/_helpers/restrict_event_time.do"

        * Controls; ln_aum_std standardizes the level of combined AUM (dollar_aumc),
        * not its log, as in the Table IX estimation sample
            gen interaction = treated*post
            gen ln_employees = ln(employees)
            gen ln_aum = ln(dollar_aumc)
            egen ln_employees_std = std(ln_employees)
            egen ln_aum_std = std(dollar_aumc)
            gen ln_age = ln(combined_agec)
            egen ln_age_z = std(ln_age)

        * Winsorize and save
            do "$PKG/_rules/winsorize_last.do" ix_final "fraction_bad_a_flow fraction_bad_e_flow combined_aumg combined_clg"
            isid id treated event_time
            save "`saving'", replace
    end

* Build the estimation sample from the rebuilt cells
    assemble_panel, realfile("$DATA/postmergercombinedfirm_rebuilt.dta") ///
                    cffile("$DATA/postmergercombinedfirmcf_rebuilt.dta") saving("$DATA/adviser_event_panel_rebuilt.dta")

* Load the Table IX estimation sample after its final winsorization
    preserve
        use "$SRC/output/adviser_event_panel", clear
        do "$PKG/_rules/winsorize_last.do" ix_final "fraction_bad_a_flow fraction_bad_e_flow combined_aumg combined_clg"
        keep id treated event_time fraction_bad_a_flow fraction_bad_e_flow employees both_retailc ln_aum_std ln_age_z ln_employees_std cohort year_aum
        foreach v in fraction_bad_a_flow fraction_bad_e_flow employees both_retailc ln_aum_std ln_age_z ln_employees_std cohort year_aum {
            rename `v' `v'_ix
        }
        tempfile A_ix_sample
        save `A_ix_sample'
    restore

* Check that the rebuilt sample equals the Table IX estimation sample
    use "$DATA/adviser_event_panel_rebuilt", clear
    merge 1:1 id treated event_time using `A_ix_sample', assert(3) nogen
    foreach v in fraction_bad_a_flow fraction_bad_e_flow employees both_retailc ln_aum_std ln_age_z ln_employees_std cohort year_aum {
        assert abs(`v' - `v'_ix) < 1e-6
    }
    display "A7_FULL_SAMPLE_MATCHES_TABLE_IX=1"


********************************************************************************
* Part D. Compare the rebuilt estimation sample with adviser_event_panel.dta
********************************************************************************

* Merge the rebuilt sample with adviser_event_panel.dta
    use "$DATA/adviser_event_panel_rebuilt.dta", clear
    count
    local n_rebuilt = r(N)
    merge 1:1 id treated event_time using "$SRC/output/adviser_event_panel"
    tab _merge

* For each variable, post the number of differing rows and the largest difference
    tempname S
    postfile `S' str40 variable long n_matched n_diff double max_abs_diff using "$DATA/sample_comparison.dta", replace
    foreach v in year_aum employees fraction_bad_a_flow fraction_bad_e_flow dollar_aumc number_clientsc both_retailc combined_agec combined_aumg combined_clg cohort post interaction ln_employees ln_aum ln_employees_std ln_aum_std ln_age ln_age_z min_event max_event target_crd acquirer_crd acquired_year {
        preserve
            keep if _merge == 3
            keep id treated event_time `v'
            ren `v' `v'_rebuilt
            tempfile mine
            save `mine'
            use "$SRC/output/adviser_event_panel", clear
            keep id treated event_time `v'
            merge 1:1 id treated event_time using `mine', keep(3) nogen
            gen __d = `v' - `v'_rebuilt
            qui sum __d
            local maxabs = max(abs(r(min)), abs(r(max)))
            qui count if abs(__d) > 1e-5
            post `S' ("`v'") (_N) (r(N)) (`maxabs')
        restore
    }

* Close, list and export the sample comparison
    postclose `S'
    use "$DATA/sample_comparison.dta", clear
    list, noobs
    export delimited using "$OUT/baseline_sample_comparison.csv", replace

* List pair-years present in only one of the rebuilt sample and adviser_event_panel.dta
    use "$DATA/adviser_event_panel_rebuilt.dta", clear
    merge 1:1 id treated event_time using "$SRC/output/adviser_event_panel"
    list id treated event_time acquired_year target_crd acquirer_crd year_aum employees fraction_bad_a_flow _merge if _merge != 3, noobs


********************************************************************************
* Part E. Estimate Table IX on the rebuilt sample and compare with the targets
********************************************************************************

* Open the estimates and comparison results files
    tempname H C
    postfile `H' str40 sample str12 model int col str32 var double b se t p str5 stars long N int nclust double r2_a r2 df_r using "$DATA/rebuilt_estimates.dta", replace
    postfile `C' str40 target str12 model int col str32 var str8 stat double target_value reproduced difference str5 result using "$DATA/comparison_stage2.dta", replace

* Estimate Table IX on the rebuilt sample and compare with the paper and pipeline tables
    use "$DATA/adviser_event_panel_rebuilt.dta", clear
    label_baseline
    eststo clear
    run_baseline_regs, prefix(r)
    esttab r1 r2 r3 r4, $ESTTAB_OPTS
    esttab r1 r2 r3 r4 using "$DATA/rebuilt_tableIX.tex", replace $ESTTAB_OPTS
    post_estimates, sample("rebuilt_tableIX") models(r1 r2 r3 r4) handle(`H')
    compare_to_target, target("tableIX_paper") targetfile("$DATA/targets_manuscript.dta") models(r1 r2 r3 r4) handle(`C')
    compare_to_target, target("tableIX_pipeline") targetfile("$DATA/targets_pipeline.dta") models(r1 r2 r3 r4) handle(`C')
    postclose `H'
    postclose `C'

* Tag the stage 2 comparison and list any failures
    use "$DATA/comparison_stage2.dta", clear
    gen stage = "stage2_rebuilt_pipeline"
    order stage
    save "$DATA/comparison_stage2.dta", replace
    tab target result
    list target model var stat target_value reproduced difference result if result == "FAIL", noobs sepby(target)

* Combine the stage 1 and stage 2 comparisons
    use "$DATA/comparison_stage1.dta", clear
    append using "$DATA/comparison_stage2.dta"
    export delimited using "$OUT/baseline_comparison.csv", replace
    tab stage target if stat == "N"
    bys stage target: egen anyfail = max(result == "FAIL")
    tab stage target if stat == "N", sum(anyfail)

log close
