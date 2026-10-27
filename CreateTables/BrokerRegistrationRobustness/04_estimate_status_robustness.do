********************************************************************************
* Estimates the four columns of Table IX on the full sample and on every
* status-restricted sample, and writes the panel tables, machine-readable
* estimates, sample diagnostics and validation checks to $OUT.
* 05_appendix_exam_table.do uses these results to write Table A.8.
********************************************************************************

* Load settings, open the log and record the Stata version
    do "_settings.do"
    cap log close
    log using "$LOGS/04_estimate_status_robustness.log", replace text
    di as text _n "Stata: " c(stata_version) " " c(edition_real) " born " c(born_date) " cores " c(processors)

* Full sample and the four status-restricted subsets
    local subsets full anybroker brokeronly iaronly dual


********************************************************************************
* Estimation on every sample
********************************************************************************

* Run the four baseline regressions for each basis and subset and post the estimates
    tempname H
    postfile `H' str40 sample str12 model int col str32 var double b se t p str5 stars long N int nclust double r2_a r2 df_r using "$DATA/robustness_estimates.dta", replace
    eststo clear
    foreach basis in reg exam {
        foreach s of local subsets {
            use "$DATA/est_`basis'_`s'", clear
            label_baseline
            run_baseline_regs, prefix(`basis'_`s'_)
            di as text _n "===== basis=`basis' subset=`s'"
            esttab `basis'_`s'_1 `basis'_`s'_2 `basis'_`s'_3 `basis'_`s'_4, $ESTTAB_OPTS
            post_estimates, sample("`basis':`s'") models(`basis'_`s'_1 `basis'_`s'_2 `basis'_`s'_3 `basis'_`s'_4) handle(`H')
        }
    }
    postclose `H'


********************************************************************************
* Sample diagnostics per basis and subset
********************************************************************************

* Open the diagnostics postfile
    tempname G
    postfile `G' str6 basis str12 subset str40 stat double value using "$DATA/diagnostics_long.dta", replace

* Diagnostics for each basis
    foreach basis in reg exam {
        * Map estimation cells back to the person-firm-year rows with their t-1 status,
        * to count the distinct individuals contributing to the denominator
        foreach side in real cf {
            if "`side'" == "real" local f event_panel_real
            else local f event_panel_pseudo
            use id b_crd_number year using "$SRC/output_robust/`f'", clear
            merge m:1 id b_crd_number using "$DATA/status_t1_`side'", keep(3) nogen keepusing(`basis'_status)
            ren year year_aum
            gen treated = ("`side'" == "real")
            save "$DATA/tmp_panelkeys_`side'", replace
        }
        foreach s of local subsets {
            * Observations, merger events, pseudo pairs and cohorts
            use "$DATA/est_`basis'_`s'", clear
            qui count
            post `G' ("`basis'") ("`s'") ("N_obs") (r(N))
            egen __t1 = tag(id) if treated == 1
            qui count if __t1 == 1
            post `G' ("`basis'") ("`s'") ("real_merger_events") (r(N))
            egen __t0 = tag(id) if treated == 0
            qui count if __t0 == 1
            post `G' ("`basis'") ("`s'") ("pseudo_pairs") (r(N))
            egen __tc = tag(cohort)
            qui count if __tc == 1
            post `G' ("`basis'") ("`s'") ("cohorts_clusters") (r(N))
            drop __t1 __t0 __tc
            * Mean outcomes before the merger and over the full window
            qui sum fraction_bad_a_flow if treated == 1 & post == 0
            post `G' ("`basis'") ("`s'") ("mean_pre_outcome_all_treated") (r(mean))
            qui sum fraction_bad_e_flow if treated == 1 & post == 0
            post `G' ("`basis'") ("`s'") ("mean_pre_outcome_ems_treated") (r(mean))
            qui sum fraction_bad_a_flow if treated == 0 & post == 0
            post `G' ("`basis'") ("`s'") ("mean_pre_outcome_all_pseudo") (r(mean))
            qui sum fraction_bad_e_flow if treated == 0 & post == 0
            post `G' ("`basis'") ("`s'") ("mean_pre_outcome_ems_pseudo") (r(mean))
            qui sum fraction_bad_a_flow
            post `G' ("`basis'") ("`s'") ("mean_outcome_all") (r(mean))
            qui sum fraction_bad_e_flow
            post `G' ("`basis'") ("`s'") ("mean_outcome_ems") (r(mean))
            * Employee denominators and share of headcount retained
            qui sum employees_restricted
            post `G' ("`basis'") ("`s'") ("mean_employee_denominator_restricted") (r(mean))
            qui sum employees_full
            post `G' ("`basis'") ("`s'") ("mean_employee_denominator_full") (r(mean))
            gen share_ret = employees_restricted/employees_full
            qui sum share_ret
            post `G' ("`basis'") ("`s'") ("mean_share_of_headcount_retained") (r(mean))
            qui sum persons_restricted
            post `G' ("`basis'") ("`s'") ("mean_distinct_persons_restricted") (r(mean))
            qui sum employees_restricted if treated == 1
            post `G' ("`basis'") ("`s'") ("mean_employee_denominator_restricted_treated") (r(mean))
            qui sum employees_restricted if treated == 0
            post `G' ("`basis'") ("`s'") ("mean_employee_denominator_restricted_pseudo") (r(mean))
            * Distinct individuals in the denominator across all retained cells
            keep id treated year_aum
            tempfile keys
            save `keys'
            local tot = 0
            foreach side in real cf {
                use "$DATA/tmp_panelkeys_`side'", clear
                merge m:1 id treated year_aum using `keys', keep(3) nogen
                if "`s'" == "anybroker"  keep if inlist(`basis'_status, 1, 3)
                if "`s'" == "brokeronly" keep if `basis'_status == 1
                if "`s'" == "iaronly"    keep if `basis'_status == 2
                if "`s'" == "dual"       keep if `basis'_status == 3
                egen __tp = tag(b_crd_number)
                qui count if __tp == 1
                post `G' ("`basis'") ("`s'") ("distinct_individuals_denominator_`side'") (r(N))
                local tot = `tot' + r(N)
            }
            post `G' ("`basis'") ("`s'") ("distinct_individuals_denominator_total") (`tot')
        }
    }
    postclose `G'

* Add attrition statistics to the diagnostics
    use "$DATA/diagnostics_long.dta", clear
    append using "$DATA/attrition.dta"
    save "$DATA/diagnostics_long.dta", replace

* Shorten statistic names so the wide layout fits Stata's 32-character limit
    foreach pair in "mean_employee_denominator mean_emp_den" "distinct_individuals_denominator distinct_ind_den" ///
        "rows_with_zero_restricted_denominator rows_zero_restr_den" "cohorts_with_any_zero_denominator_cell cohorts_any_zero_den_cell" ///
        "mean_share_of_headcount_retained mean_share_headcount_ret" "mean_distinct_persons_restricted mean_distinct_persons_restr" ///
        "real_events_full_sample real_events_full" "rows_lost_vs_full_sample rows_lost_vs_full" "rows_added_vs_full_sample rows_added_vs_full" {
        tokenize `pair'
        replace stat = subinstr(stat, "`1'", "`2'", 1)
    }
    assert length(stat) <= 31

* Reshape to one row per basis and subset and export sample_diagnostics.csv
    ren value v
    reshape wide v, i(basis subset) j(stat) string
    ren v* *
    gen order = cond(subset == "full", 1, cond(subset == "anybroker", 2, cond(subset == "brokeronly", 3, cond(subset == "iaronly", 4, 5))))
    sort basis order
    drop order
    export delimited using "$OUT/sample_diagnostics.csv", replace
    list basis subset N_obs real_merger_events pseudo_pairs distinct_ind_den_total mean_emp_den_restricted, noobs


********************************************************************************
* Machine-readable regression results
********************************************************************************

* Split the sample identifier into basis, subset and panel letter
    use "$DATA/robustness_estimates.dta", clear
    gen basis = substr(sample, 1, strpos(sample, ":") - 1)
    gen subset = substr(sample, strpos(sample, ":") + 1, .)
    gen panel = cond(subset == "full", "A", cond(subset == "anybroker", "B", cond(subset == "brokeronly", "C", cond(subset == "iaronly", "D", "E"))))

* Describe each sample in words
    gen sample_label = ""
    replace sample_label = "Full sample (replication)" if subset == "full"
    replace sample_label = "Any broker at t-1 (BD representative registration, alone or dual)" if subset == "anybroker" & basis == "reg"
    replace sample_label = "Broker only at t-1 (BD representative registration, no IAR registration)" if subset == "brokeronly" & basis == "reg"
    replace sample_label = "IAR only at t-1 (IAR registration, no BD representative registration)" if subset == "iaronly" & basis == "reg"
    replace sample_label = "Dual at t-1 (BD representative and IAR registration)" if subset == "dual" & basis == "reg"
    replace sample_label = "Any broker-qualified at t-1 (Series 6 or 7, alone or with IAR qualification)" if subset == "anybroker" & basis == "exam"
    replace sample_label = "Broker-qualified only at t-1 (Series 6 or 7, no IAR qualification)" if subset == "brokeronly" & basis == "exam"
    replace sample_label = "IAR-qualified only at t-1 (Series 65, or 66 with 7; no Series 6/7)" if subset == "iaronly" & basis == "exam"
    replace sample_label = "Dual qualified at t-1 (Series 6/7 and IAR qualification)" if subset == "dual" & basis == "exam"

* Label outcomes and controls, order columns and export the csv
    gen depvar = cond(col <= 2, "fraction_bad_a_flow (All)", "fraction_bad_e_flow (EMS)")
    gen controls = cond(inlist(col, 2, 4), "baseline controls", "none")
    order basis panel subset sample_label col depvar controls var b se t p stars N nclust r2_a r2 df_r
    drop sample model
    export delimited using "$OUT/registration_status_robustness.csv", replace


********************************************************************************
* Panel tables
********************************************************************************

* Program that writes one panel table (Panels A-E) for a given status basis
    cap program drop write_panel_table
    program define write_panel_table
        * Table text comes in through the globals TBL_NOTES and PLAB1..PLAB5 (LaTeX
        * strings with braces and backslashes do not survive -syntax- parsing)
        syntax , basis(string) file(string) title(string) label(string)
        local notes `"$TBL_NOTES"'
        local subsets full anybroker brokeronly iaronly dual

        * Open the file and write the table preamble and column headers
        tempname fh
        file open `fh' using "`file'", write text replace
        file write `fh' "\begin{table}[!htbp]" _n
        file write `fh' "\scriptsize" _n
        file write `fh' "\centering" _n
        file write `fh' "\captionsetup{font=small, labelfont=bf}" _n
        file write `fh' "\caption{\textbf{`title'}}" _n
        file write `fh' "\begin{threeparttable}" _n
        file write `fh' "\begin{tablenotes}\footnotesize\item `notes'\end{tablenotes}" _n
        file write `fh' "\vskip 1.5em" _n
        file write `fh' "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
        file write `fh' "\begin{tabular}{l*{4}{c}}" _n
        file write `fh' "\toprule" _n
        file write `fh' "& \multicolumn{2}{c}{\textbf{Employee Disclosure (All)}} & \multicolumn{2}{c}{\textbf{Employee Misconduct (EMS)}} \\" _n
        file write `fh' "\cmidrule(r){2-3}\cmidrule(r){4-5}" _n
        file write `fh' "& \multicolumn{1}{c}{(1)} & \multicolumn{1}{c}{(2)} & \multicolumn{1}{c}{(3)} & \multicolumn{1}{c}{(4)} \\" _n
        file write `fh' "\midrule" _n

        * One panel per subset
        local k = 0
        foreach s of local subsets {
            local ++k
            local plab `"${PLAB`k'}"'
            local pletter = word("A B C D E", `k')
            file write `fh' "\multicolumn{5}{l}{\textit{Panel `pletter': `plab'}} \\" _n
            file write `fh' "[0.3em]" _n
            * Coefficient and standard-error rows for Merged X Post, Merged and Post
            foreach v in interaction treated post {
                if "`v'" == "interaction" local vl "Merged X Post"
                if "`v'" == "treated" local vl "Merged"
                if "`v'" == "post" local vl "Post"
                local rowb "`vl'"
                local rowse ""
                forvalues c = 1/4 {
                    qui est restore `basis'_`s'_`c'
                    local b = _b[`v']
                    local se = _se[`v']
                    local t = `b'/`se'
                    local p = 2*ttail(e(df_r), abs(`t'))
                    local st = cond(`p' < 0.01, "***", cond(`p' < 0.05, "**", cond(`p' < 0.10, "*", "")))
                    local bs : display %9.3f `b'
                    local ses : display %9.3f `se'
                    if "`st'" != "" local rowb "`rowb' & `=strtrim("`bs'")'\sym{`st'}"
                    else local rowb "`rowb' & `=strtrim("`bs'")'"
                    local rowse "`rowse' & (`=strtrim("`ses'")')"
                }
                file write `fh' "`rowb' \\" _n
                file write `fh' "`rowse' \\" _n
            }
            * Observations and adjusted R2
            local rowN "Observations"
            local rowR "Adjusted \(R^{2}\)"
            forvalues c = 1/4 {
                qui est restore `basis'_`s'_`c'
                local Ns : display %12.0fc e(N)
                local Rs : display %9.3f e(r2_a)
                local rowN "`rowN' & `=strtrim("`Ns'")'"
                local rowR "`rowR' & `=strtrim("`Rs'")'"
            }
            file write `fh' "`rowN' \\" _n
            file write `fh' "`rowR' \\" _n
            * Read this subset's diagnostics
            preserve
            use "$DATA/diagnostics_long.dta", clear
            keep if basis == "`basis'" & subset == "`s'"
            local j = 0
            foreach st in real_merger_events pseudo_pairs distinct_individuals_denominator_total mean_pre_outcome_all_treated mean_pre_outcome_ems_treated mean_employee_denominator_restricted mean_share_of_headcount_retained {
                local ++j
                qui sum value if stat == "`st'"
                local d`j' = r(mean)
            }
            restore
            * Write the diagnostics rows, one value repeated across the four columns
            local v_real_merger_events `d1'
            local v_pseudo_pairs `d2'
            local v_distinct `d3'
            local v_mean_pre_outcome_all_treated `d4'
            local v_mean_pre_outcome_ems_treated `d5'
            local v_mean_emp_den `d6'
            local v_mean_share `d7'
            local x : display %12.0fc `v_real_merger_events'
            local x = strtrim("`x'")
            file write `fh' "Real merger events retained & `x' & `x' & `x' & `x' \\" _n
            local x : display %12.0fc `v_pseudo_pairs'
            local x = strtrim("`x'")
            file write `fh' "Pseudo-merger pairs retained & `x' & `x' & `x' & `x' \\" _n
            local x : display %12.0fc `v_distinct'
            local x = strtrim("`x'")
            file write `fh' "Distinct individuals in denominator & `x' & `x' & `x' & `x' \\" _n
            local xa : display %9.3f `v_mean_pre_outcome_all_treated'
            local xe : display %9.3f `v_mean_pre_outcome_ems_treated'
            local xa = strtrim("`xa'")
            local xe = strtrim("`xe'")
            file write `fh' "Mean pre-merger outcome, merged firms & `xa' & `xa' & `xe' & `xe' \\" _n
            local x : display %12.1fc `v_mean_emp_den'
            local x = strtrim("`x'")
            file write `fh' "Mean employee denominator & `x' & `x' & `x' & `x' \\" _n
            local x : display %9.3f `v_mean_share'
            local x = strtrim("`x'")
            file write `fh' "Mean share of full headcount retained & `x' & `x' & `x' & `x' \\" _n
            file write `fh' "\midrule" _n
        }

        * Fixed-effect rows and table closing
        file write `fh' "Controls & No & Yes & No & Yes \\" _n
        file write `fh' "Year FE & X & X & X & X \\" _n
        file write `fh' "Cohort-clustered SE & X & X & X & X \\" _n
        file write `fh' "\bottomrule" _n
        file write `fh' "\end{tabular}}" _n
        file write `fh' "\end{threeparttable}" _n
        file write `fh' "\label{`label'}" _n
        file write `fh' "\end{table}" _n
        file close `fh'
    end

* Table notes shared by both bases, then the basis-specific additions
    local notes_common "The unit of observation is a real or pseudo target--acquirer pair in event year \(t\), from \(t=-3\) to \(t=+3\) around mergers completed between 2011 and 2020, with the same sample rules, controls, year fixed effects, cohort clustering and 1\%/99\% winsorization as Table~\ref{post_misc_regs_two}. Panel A reproduces that table. In Panels B--E, each individual is assigned one status measured in the year before the merger (\(t-1\)) and held fixed over the event window; both the disclosure numerator and the employee denominator are then recomputed from the individuals with that status, so that the dependent variable is the count of disclosure events initiated in years \(t-2\) through \(t\) by those individuals, per 100 such individuals registered with either firm of the pair in year \(t\). Individuals with no classifiable status at \(t-1\) (including those not registered in the industry at \(t-1\), such as post-merger hires new to the industry) are excluded from both numerator and denominator. Firm-level controls, including the number of employees, are measured on the full firm. Status is not evidence that an individual served retail clients. Coefficients are in percentage points. Standard errors, clustered by cohort, are in parentheses. \(^{***}\), \(^{**}\) and \(^{*}\) denote significance at the 1\%, 5\% and 10\% levels."

    local notes_reg "`notes_common' Status is based on the BrokerCheck/IAPD registration histories: an individual is a broker (BD representative) at \(t-1\) if a broker-dealer registration spell covers that year and an IAR if an investment-adviser-representative registration spell covers that year; dual means both. Any broker equals broker only plus dual."
    local notes_exam "`notes_common' Status is based on cumulative qualification exams passed by \(t-1\) (not on registration): broker-qualified means a Series 6 or Series 7 pass; IAR-qualified means a Series 65 pass, or a Series 66 pass together with a Series 7 pass; the SIE alone is not treated as broker evidence. Dual means both qualifications; any broker-qualified equals broker-qualified only plus dual."

* Write the registration-basis table
    global TBL_NOTES `"`notes_reg'"'
    global PLAB1 "Full sample (replication)"
    global PLAB2 "Any broker at \(t-1\) (BD representative registration, alone or dual)"
    global PLAB3 "Broker only at \(t-1\)"
    global PLAB4 "IAR only at \(t-1\)"
    global PLAB5 "Dual BD representative and IAR at \(t-1\)"
    write_panel_table, basis(reg) file("$OUT/registration_status_robustness.tex") ///
        title("Post-merger misconduct by pre-merger individual registration status") label("post_misc_regs_regstatus")

* Write the exam-basis table and display the registration-basis table
    global TBL_NOTES `"`notes_exam'"'
    global PLAB2 "Any broker-qualified at \(t-1\) (Series 6 or 7, alone or dual)"
    global PLAB3 "Broker-qualified only at \(t-1\)"
    global PLAB4 "IAR-qualified only at \(t-1\)"
    global PLAB5 "Dual qualified at \(t-1\)"
    write_panel_table, basis(exam) file("$OUT/exam_status_robustness.tex") ///
        title("Post-merger misconduct by pre-merger individual exam qualification") label("post_misc_regs_examstatus")
    type "$OUT/registration_status_robustness.tex"


********************************************************************************
* Validation checks (explicit, machine-readable)
********************************************************************************

* Open the validation postfile
    tempname V
    postfile `V' str80 check str6 result str200 detail using "$DATA/validation_checks.dta", replace

* (a) Panel A reproduces the baseline estimated in 02_rebuild_baseline_outcomes.do exactly
    use "$DATA/rebuilt_estimates.dta", clear
    keep if sample == "rebuilt_tableIX"
    ren (b se N r2_a) (b0 se0 N0 r2a0)
    keep col var b0 se0 N0 r2a0
    tempfile base0
    save `base0'
    use "$DATA/robustness_estimates.dta", clear
    keep if sample == "reg:full"
    merge 1:1 col var using `base0', keep(3) nogen
    qui count
    local n = r(N)
    qui count if abs(b - b0) > 1e-8 | (abs(se - se0) > 1e-8 & se != .) | N != N0 | abs(r2_a - r2a0) > 1e-8
    post `V' ("Full-sample panel reproduces the step 02 rebuilt baseline (coefficients, SEs, N, adj. R2)") (cond(r(N) == 0, "PASS", "FAIL")) ("`n' statistics compared, `r(N)' differ beyond 1e-8")

* (b) Panel A vs Table IX in the paper (3-decimal precision)
    tempname C
    postfile `C' str40 target str12 model int col str32 var str8 stat double target_value reproduced difference str5 result using "$DATA/comparison_stage4.dta", replace
    compare_to_target, target("tableIX_paper") targetfile("$DATA/targets_manuscript.dta") models(reg_full_1 reg_full_2 reg_full_3 reg_full_4) handle(`C')
    compare_to_target, target("tableIX_pipeline") targetfile("$DATA/targets_pipeline.dta") models(reg_full_1 reg_full_2 reg_full_3 reg_full_4) handle(`C')
    postclose `C'

* Count the displayed statistics that differ from each target
    use "$DATA/comparison_stage4.dta", clear
    foreach t in tableIX_pipeline tableIX_paper {
        qui count if target == "`t'"
        local n = r(N)
        qui count if target == "`t'" & result == "FAIL"
        post `V' ("Full-sample panel matches `t' at displayed precision") (cond(r(N) == 0, "PASS", "FAIL")) ("`n' displayed statistics compared, `r(N)' differ")
    }

* (c) One t-1 status per id x b_crd_number; classification year strictly before merger
    foreach side in real cf {
        use "$DATA/status_t1_`side'", clear
        cap isid id b_crd_number
        post `V' ("One fixed t-1 status per id x b_crd_number (`side' panel)") (cond(_rc == 0, "PASS", "FAIL")) ("`=_N' person-events")
        qui count if year_t1 >= acquired_year
        post `V' ("Classification year is acquired_year-1 for every person-event (`side' panel)") (cond(r(N) == 0, "PASS", "FAIL")) ("`r(N)' violations")
        qui count if missing(reg_status) | missing(exam_status)
        post `V' ("No missing status codes; unclassified is an explicit category (`side' panel)") (cond(r(N) == 0, "PASS", "FAIL")) ("`r(N)' missing")
    }

* (d) Cell-level checks on every restricted aggregation
    foreach basis in reg exam {
        foreach side in real cf {
            use "$DATA/cells_`basis'_`side'", clear
            local bad = 0
            local badp = 0
            local badr = 0
            foreach s of local subsets {
                qui count if employees_`s' > employees_full
                local bad = `bad' + r(N)
                qui count if persons_pos_any_`s' > persons_`s' | persons_pos_egan_`s' > persons_`s'
                local badp = `badp' + r(N)
                qui count if (any_misconduct_`s' < 0 | egan_misconduct_`s' < 0) & any_misconduct_`s' != .
                local badr = `badr' + r(N)
            }
            post `V' ("Restricted denominator never exceeds full denominator (`basis', `side')") (cond(`bad' == 0, "PASS", "FAIL")) ("`bad' cells")
            post `V' ("Persons with a disclosure never exceed persons in denominator (`basis', `side')") (cond(`badp' == 0, "PASS", "FAIL")) ("`badp' cells")
            post `V' ("Every nonmissing rate is non-negative (`basis', `side')") (cond(`badr' == 0, "PASS", "FAIL")) ("`badr' cells")
            qui count if employees_full == 0
            post `V' ("No cell has a zero full denominator (`basis', `side')") (cond(r(N) == 0, "PASS", "FAIL")) ("`r(N)' cells")
        }
    }

* Count cells with a rate above 100 (informational): the count-based outcome is
* not bounded by 100 because a person can carry several disclosure events, so the
* bound is checked on persons with a disclosure in (d)
    foreach basis in reg exam {
        foreach side in real cf {
            use "$DATA/cells_`basis'_`side'", clear
            local over = 0
            foreach s of local subsets {
                qui count if any_misconduct_`s' > 100 & any_misconduct_`s' != .
                local over = `over' + r(N)
            }
            post `V' ("Rates above 100 (count-based outcome, informational) (`basis', `side')") ("INFO") ("`over' cell-subset combinations exceed 100 before winsorization")
        }
    }

* (e) Same balance rules for treated and pseudo rows in every estimation sample
    foreach basis in reg exam {
        foreach s of local subsets {
            use "$DATA/est_`basis'_`s'", clear
            bys id event_time: egen nt = nvals(treated)
            qui count if nt != 2
            local b1 = r(N)
            qui count if !(min_event <= -1 & max_event >= 0) | event_time < -3 | event_time > 3
            local b2 = r(N)
            qui count if employees_restricted < 1
            local b3 = r(N)
            post `V' ("Balance rules hold for treated and pseudo rows (`basis':`s')") (cond(`b1' + `b2' == 0, "PASS", "FAIL")) ("`b1' unbalanced cells, `b2' window violations")
            post `V' ("Every retained cell has at least one qualifying individual (`basis':`s')") (cond(`b3' == 0, "PASS", "FAIL")) ("`b3' cells")
        }
    }
    postclose `V'

* Export validation_checks.csv and list the results
    use "$DATA/validation_checks.dta", clear
    export delimited using "$OUT/validation_checks.csv", replace
    list, noobs sep(0)

* Remove temporary files and close the log
    cap erase "$DATA/tmp_panelkeys_real.dta"
    cap erase "$DATA/tmp_panelkeys_cf.dta"
    log close
