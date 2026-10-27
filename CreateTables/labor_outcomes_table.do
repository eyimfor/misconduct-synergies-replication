********************************************************************************
* Builds Table A.9 (separationmerger.tex): labor-market outcomes of target and
* acquirer advisers around the merger. Uses the Table X target and acquirer
* panels, so run it after those are saved. It tabulates shares, fits no
* regressions and leaves the Table X panels unchanged.
********************************************************************************
clear

* Build the employment history and roster (sample definitions are in
* _rules/labor_outcomes.do)
    tempfile labor_history labor_roster labor_summary labor_diagnostics
    do "$PKG/_rules/labor_outcomes.do" history
    save `labor_history'
    do "$PKG/_rules/labor_outcomes.do" roster
    save `labor_roster'

* Open the result and diagnostic post files
    tempname labor_results labor_checks
    postfile `labor_results' str8 panel byte misconduct post outcome double numerator denominator percent using `labor_summary'
    postfile `labor_checks' str8 panel byte misconduct post double sample_rows leavers left_industry join_different return_only followup_min followup_max followup_mean endpoint using `labor_diagnostics'


********************************************************************************
* Outcome shares by panel, misconduct and pre/post period
********************************************************************************

* Tabulate the target and acquirer panels
    foreach role in target acquirer {
        * Load the panel sample and save its original variables
            do "$PKG/_rules/labor_outcomes.do" sample `role'
            local labor_n = _N
            unab labor_allvars : _all
            ds labor_*
            local labor_newvars `r(varlist)'
            local labor_originalvars : list labor_allvars - labor_newvars
            tempfile labor_original
            preserve
                keep `labor_originalvars'
                save `labor_original'
            restore

        * Attach the labor outcomes and confirm the panel's rows and original
        * variables are unchanged
            do "$PKG/_rules/labor_outcomes.do" attach "`labor_history'" "`labor_roster'"
            assert _N == `labor_n'
            sort labor_source_row
            cf `labor_originalvars' using `labor_original', all
            save data/output/labor_outcomes_`role', replace

        * Count, summarize and post each misconduct-by-period cell
            forvalues misconduct = 0/1 {
                forvalues post = 0/1 {
                    * Count the cell and its leavers; the three leaver
                    * outcomes add up to all leavers
                        quietly count if any_intensity_sum_z == `misconduct' & post_merger == `post'
                        local n = r(N)
                        quietly count if any_intensity_sum_z == `misconduct' & post_merger == `post' & separation == 100
                        local leave = r(N)
                        quietly count if any_intensity_sum_z == `misconduct' & post_merger == `post' & labor_left_industry == 1
                        local left = r(N)
                        quietly count if any_intensity_sum_z == `misconduct' & post_merger == `post' & labor_join_different == 1
                        local different = r(N)
                        quietly count if any_intensity_sum_z == `misconduct' & post_merger == `post' & labor_return_only == 1
                        local returned = r(N)
                        assert `left' + `different' + `returned' == `leave'

                    * Follow-up years of leavers
                        quietly summarize labor_followup_years if any_intensity_sum_z == `misconduct' & post_merger == `post' & separation == 100, meanonly
                        local follow_min = r(min)
                        local follow_max = r(max)
                        local follow_mean = r(mean)

                    * Post the diagnostics and the four outcome shares
                        post `labor_checks' ("`role'") (`misconduct') (`post') (`n') (`leave') (`left') (`different') (`returned') (`follow_min') (`follow_max') (`follow_mean') (scalar(LABOR_history_last_year))
                        post `labor_results' ("`role'") (`misconduct') (`post') (1) (`n' - `leave') (`n') (100 * (`n' - `leave') / `n')
                        post `labor_results' ("`role'") (`misconduct') (`post') (2) (`leave') (`n') (100 * `leave' / `n')
                        post `labor_results' ("`role'") (`misconduct') (`post') (3) (`left') (`leave') (100 * `left' / `leave')
                        post `labor_results' ("`role'") (`misconduct') (`post') (4) (`different') (`leave') (100 * `different' / `leave')
                }
            }
    }

* Close the post files
    postclose `labor_results'
    postclose `labor_checks'

* Check and list the diagnostics
    use `labor_diagnostics', clear
    assert _N == 8
    assert left_industry + join_different + return_only == leavers
    gen double return_only_percent = 100 * return_only / leavers
    gen double history_source_rows = scalar(LABOR_history_rows)
    gen double history_invalid_key_rows = scalar(LABOR_invalid_history_rows)
    gen double history_employer_keys = scalar(LABOR_history_employer_keys)
    gen int history_first_year = scalar(LABOR_history_first_year)
    order panel misconduct post sample_rows leavers left_industry join_different return_only return_only_percent
    list, noobs abbreviate(22)

* Check and label the outcome shares
    use `labor_summary', clear
    assert _N == 32
    isid panel misconduct post outcome
    assert percent >= 0 & percent <= 100 if denominator > 0
    assert missing(percent) if denominator == 0
    label define labor_outcome 1 "Remain with Firm" 2 "Leave Firm" 3 "Left Industry" 4 "Join a Different Firm"
    label values outcome labor_outcome
    sort panel outcome misconduct post


********************************************************************************
* Write separationmerger.tex
********************************************************************************

* Open the file and write the table head
    tempname labor_tex
    file open `labor_tex' using tables/separationmerger.tex, write replace text
    file write `labor_tex' "% Left Industry plus Join a Different Firm can be below 100 due to return-only cases." _n
    file write `labor_tex' "{\begin{tabular}{lcccc}" _n "\toprule" _n

* One panel per role, one row per outcome, one column per misconduct and period
    foreach role in target acquirer {
        if "`role'" == "target" local heading "Panel A: Target Firm Employees"
        if "`role'" == "acquirer" local heading "Panel B: Acquiring Firm Employees"
        file write `labor_tex' "\textbf{`heading'} & \multicolumn{2}{c}{No Misconduct} & \multicolumn{2}{c}{Misconduct} \\" _n
        file write `labor_tex' " & Pre & Post & Pre & Post \\" _n "\midrule" _n
        forvalues outcome = 1/4 {
            local label : label labor_outcome `outcome'
            file write `labor_tex' "`label'"
            forvalues misconduct = 0/1 {
                forvalues post = 0/1 {
                    quietly summarize percent if panel == "`role'" & outcome == `outcome' & misconduct == `misconduct' & post == `post', meanonly
                    if r(N) == 1 file write `labor_tex' " & " %3.0f (r(mean)) "\%"
                    else file write `labor_tex' " & --"
                }
            }
            file write `labor_tex' " \\" _n
        }
        file write `labor_tex' "\bottomrule" _n
    }

* Close the table
    file write `labor_tex' "\end{tabular}}" _n
    file close `labor_tex'
    display "LABOR_OUTCOMES_FINISHED=1"
