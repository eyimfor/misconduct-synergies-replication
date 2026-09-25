********************************************************************************
* Re-estimates the four Table IX columns from the pipeline's estimation sample
* (adviser_event_panel.dta) and compares them with post_misc_regs.tex and the
* published Table IX. Writes baseline_replication.tex and .csv,
* data/targets_*.dta and data/comparison_stage1.dta.
********************************************************************************
do "_settings.do"
cap log close
log using "$LOGS/01_replicate_baseline.log", replace text

* Record the Stata version and check the required ados
    di as text _n "Stata: " c(stata_version) " " c(edition_real) " born " c(born_date) " cores " c(processors)
    which reghdfe
    which esttab
    which winsor2


********************************************************************************
* 1. Parse the two target tables
********************************************************************************

* Parse the pipeline and manuscript versions of post_misc_regs.tex
    parse_esttab_tex, file("$ROOT/2023/tables/post_misc_regs.tex") saving("$DATA/targets_pipeline.dta")
    parse_esttab_tex, file("$PAPER/Tables/post_misc_regs.tex")              saving("$DATA/targets_manuscript.dta")

* List the parsed targets
    foreach t in pipeline manuscript {
        di _n as text "Parsed target: `t'"
        use "$DATA/targets_`t'.dta", clear
        list, sepby(var) noobs
    }


********************************************************************************
* 2. Re-estimate from the pipeline's estimation sample
********************************************************************************

* Load and check the estimation sample
    use "$SRC/output/adviser_event_panel", clear
    describe, short
    di as text "Estimation sample saved: " c(filedate)
    isid id treated event_time
    count

* The sample is saved before winsorization; apply the final winsorization here
    do "$PKG/_rules/winsorize_last.do" ix_final "fraction_bad_a_flow fraction_bad_e_flow combined_aumg combined_clg"

* Run the four baseline regressions and write the table
    label_baseline
    eststo clear
    run_baseline_regs, prefix(m)
    esttab m1 m2 m3 m4 using "$OUT/baseline_replication.tex", replace $ESTTAB_OPTS
    esttab m1 m2 m3 m4, $ESTTAB_OPTS

* Save machine-readable results
    tempname H
    postfile `H' str40 sample str12 model int col str32 var double b se t p str5 stars long N int nclust double r2_a r2 df_r using "$DATA/baseline_replication.dta", replace
    post_estimates, sample("tableIX_estimation_sample") models(m1 m2 m3 m4) handle(`H')
    postclose `H'
    use "$DATA/baseline_replication.dta", clear
    export delimited using "$OUT/baseline_replication.csv", replace


********************************************************************************
* 3. Compare with the target tables
********************************************************************************

* Compare each coefficient with the pipeline and paper targets
    tempname C
    postfile `C' str40 target str12 model int col str32 var str8 stat double target_value reproduced difference str5 result using "$DATA/comparison_stage1.dta", replace
    compare_to_target, target("tableIX_pipeline") targetfile("$DATA/targets_pipeline.dta") models(m1 m2 m3 m4) handle(`C')
    compare_to_target, target("tableIX_paper") targetfile("$DATA/targets_manuscript.dta") models(m1 m2 m3 m4) handle(`C')
    postclose `C'

* Save the comparison and list any failures
    use "$DATA/comparison_stage1.dta", clear
    gen stage = "stage1_pipeline_sample"
    order stage
    save "$DATA/comparison_stage1.dta", replace
    tab target result
    list target model var stat target_value reproduced difference result if result == "FAIL", noobs sepby(target)

log close
