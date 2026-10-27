********************************************************************************
* Produces Table A.8 (post-merger misconduct for broker-qualified advisers) in four
* panels: full sample, any broker qualification, broker-qualified only, dual qualified.
* Writes post_misc_regs_examqual.tex (table body, same layout as Tables IX and X)
* and post_misc_regs_examqual_wrapper.tex (LaTeX table environment with notes).
********************************************************************************

* Load settings and open the log
    do "_settings.do"
    cap log close
    log using "$LOGS/05_appendix_exam_table.log", replace text

* Subsets and their panel labels
    local subsets full anybroker brokeronly dual
    local plabA "Full sample (replication of Table~\ref{post_misc_regs_two})"
    local plabB "Broker-qualified advisers (Series 6 or 7, with or without an IAR qualification)"
    local plabC "Broker-qualified advisers without an IAR qualification"
    local plabD "Advisers with both broker and IAR qualifications"

* Run the four baseline regressions on each exam-basis subset
    eststo clear
    foreach s of local subsets {
        use "$DATA/est_exam_`s'", clear
        label_baseline
        run_baseline_regs, prefix(q_`s'_)
        di as text _n "===== exam basis, subset `s'"
        esttab q_`s'_1 q_`s'_2 q_`s'_3 q_`s'_4, $ESTTAB_OPTS
    }


********************************************************************************
* Helper for one formatted cell in the paper's esttab layout
********************************************************************************

* Return the "b\sym{stars}" cell and its standard error (blank when the variable
* is not in the model)
    cap program drop _cellb
    program define _cellb, rclass
        syntax , model(string) var(string)
        qui est restore `model'
        local vars : colnames e(b)
        local found : list var in vars
        if `found' == 0 {
            return local cell "                  "
            return local se   "                  "
            exit
        }
        local b = _b[`var']
        local se = _se[`var']
        local p = 2*ttail(e(df_r), abs(`b'/`se'))
        local st = cond(`p' < 0.01, "***", cond(`p' < 0.05, "**", cond(`p' < 0.10, "*", "")))
        local bs : display %9.3f `b'
        local ses : display %9.3f `se'
        if "`st'" != "" return local cell "`bs'\sym{`st'}"
        else return local cell "`bs'         "
        return local se "  (`=strtrim("`ses'")')         "
    end


********************************************************************************
* Table body
********************************************************************************

* Open the file and write the column headers
    tempname fh
    file open `fh' using "$OUT/post_misc_regs_examqual.tex", write text replace
    file write `fh' "& \multicolumn{2}{c}{\textbf{Employee Disclosure (All)}}" _n
    file write `fh' "&\multicolumn{2}{c}{\textbf{Employee Misconduct (EMS)}} \\[-0.4ex]" _n
    file write `fh' "\cmidrule(r){2 - 3}" _n
    file write `fh' "\cmidrule(r){4 - 5}" _n
    file write `fh' "&\multicolumn{1}{c}{(1)}         &\multicolumn{1}{c}{(2)}         &\multicolumn{1}{c}{(3)}         &\multicolumn{1}{c}{(4)}         \\" _n

* One panel per subset
    local k = 0
    foreach s of local subsets {
        local ++k
        local pl = word("A B C D", `k')
        file write `fh' "\midrule" _n
        file write `fh' "\multicolumn{5}{l}{\textbf{Panel `pl': `plab`pl''}} \\" _n
        file write `fh' "\midrule" _n
        * Only the coefficient of interest is displayed (Merged, Post and the controls
        * are estimated but hidden; the wrapper carries a Controls row)
        local nv = 0
        foreach v in interaction {
            local ++nv
            if "`v'" == "interaction" local vl "Merged X Post"
            if "`v'" == "treated" local vl "Merged"
            if "`v'" == "post" local vl "Post"
            if "`v'" == "both_retailc" local vl "Retail clients"
            if "`v'" == "ln_aum_std" local vl "Ln(Assets under management)"
            if "`v'" == "ln_age_z" local vl "Ln(Firm Age)"
            if "`v'" == "ln_employees_std" local vl "Ln(Number of employees)"
            local rowb : display %-16s "`vl'"
            local rowse "                "
            forvalues c = 1/4 {
                _cellb, model(q_`s'_`c') var(`v')
                local rowb "`rowb'&`r(cell)'"
                local rowse "`rowse'&`r(se)'"
            }
            if `nv' > 1 file write `fh' "[1em]" _n
            file write `fh' "`rowb'\\" _n
            file write `fh' "`rowse'\\" _n
        }
        * Observations and adjusted R2
        file write `fh' "\hline" _n
        local rowN "Observations    "
        local rowR "Adjusted \(R^{2}\)"
        forvalues c = 1/4 {
            qui est restore q_`s'_`c'
            local Ns : display %12.0fc e(N)
            local Rs : display %9.3f e(r2_a)
            local rowN "`rowN'&   `=strtrim("`Ns'")'         "
            local rowR "`rowR'&    `=strtrim("`Rs'")'         "
        }
        file write `fh' "`rowN'\\" _n
        file write `fh' "`rowR'\\" _n
        * Panel-specific sample rows
        preserve
        use "$DATA/diagnostics_long.dta", clear
        keep if basis == "exam" & subset == "`s'"
        qui sum value if stat == "real_merger_events"
        local ev : display %12.0fc r(mean)
        local ev = strtrim("`ev'")
        qui sum value if stat == "mean_employee_denominator_restricted"
        local den : display %12.1fc r(mean)
        local den = strtrim("`den'")
        qui sum value if stat == "mean_share_of_headcount_retained"
        local sh : display %9.3f r(mean)
        local sh = strtrim("`sh'")
        restore
        file write `fh' "Mergers         &   `ev'         &   `ev'         &   `ev'         &   `ev'         \\" _n
        file write `fh' "Share of advisers retained&    `sh'         &    `sh'         &    `sh'         &    `sh'         \\" _n
    }

* Close the table body and display it
    file write `fh' "\midrule" _n
    file close `fh'
    type "$OUT/post_misc_regs_examqual.tex"


********************************************************************************
* LaTeX table environment in the same style as Table A.7
********************************************************************************

* Write the wrapper with caption, notes and the Controls and Year FE rows
    file open `fh' using "$OUT/post_misc_regs_examqual_wrapper.tex", write text replace
    file write `fh' "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%" _n
    file write `fh' "%% Post-merger misconduct by pre-merger broker qualification %% " _n
    file write `fh' "\begin{table}[!htbp]\vspace{-1.35cm}" _n
    file write `fh' "	\scriptsize\vspace{-0.7em}\hspace*{1cm}" _n
    file write `fh' "	\setlength{\tabcolsep}{8pt}" _n
    file write `fh' "	\def\arraystretch{1.1}" _n
    file write `fh' "	\centering" _n
    file write `fh' "	\captionsetup{font=small, labelfont=bf}" _n
    file write `fh' "	\caption{\textbf{Does merging change employee misconduct? Advisers with broker qualifications}}" _n
    file write `fh' "	\begin{threeparttable}	" _n
    file write `fh' "	\begin{tablenotes}\footnotesize\item This table repeats the specification of Table~\ref{post_misc_regs_two} after restricting both the disclosure numerator and the adviser denominator to advisers with a broker qualification. The unit of observation is a real or pseudo target--acquirer pair in event year \$t\$, from \$t=-3\$ to \$t=+3\$ around mergers completed between 2011 and 2020, with the same pseudo-merged control, sample rules, controls, year fixed effects, and clustering as Table~\ref{post_misc_regs_two}. Panel A reproduces that table. In Panels B--D we classify each adviser by the qualification exams recorded in BrokerCheck and IAPD, hold the classification fixed over the event window, and recompute the numerator and the denominator of the dependent variables from the advisers in the panel's group. A broker-qualified representative passed the Series 6 or Series 7 examination in or before the year preceding the merger (\$t-1\$); an IAR-qualified representative passed the Series 65, or the Series 66 together with the Series 7, by the same year. Advisers with no qualifying exam by \$t-1\$, including post-merger hires new to the industry, are excluded from both numerator and denominator. \textit{Employee Disclosure (All)} and \textit{Employee Misconduct (EMS)} are defined as in Table~\ref{post_misc_regs_two}, per 100 advisers in the panel's group. The controls are those of Table~\ref{post_misc_regs_two} and are unchanged across panels; in particular, the number of employees counts all registered advisers of the pair, not only the advisers in the panel's group. The coefficients on \textit{Merged}, \textit{Post}, and the controls are not reported. \textit{Mergers} is the number of real mergers retained and \textit{Share of advisers retained} is the mean ratio of the panel's denominator to the full-firm denominator. Coefficients are in percentage points. We winsorize the dependent variables at the 1\% and 99\% levels. We cluster standard errors, which we report in parentheses, by cohort. \input{Caption_descriptions/star_key}\end{tablenotes}" _n
    file write `fh' "	\vskip 1.5em " _n
    file write `fh' "	\scalebox{0.95}{{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}\hspace*{-0.2cm}" _n
    file write `fh' "    \begin{tabular}{l*{4}{c}}" _n
    file write `fh' "    	\toprule" _n
    file write `fh' "	\input{Tables/post_misc_regs_examqual}" _n
    file write `fh' " Controls& &X & &X \\" _n
    file write `fh' " Year FE&X &X &X &X \\" _n
    file write `fh' "\bottomrule" _n
    file write `fh' "\end{tabular}" _n
    file write `fh' "}}" _n
    file write `fh' "\end{threeparttable}   " _n
    file write `fh' "	\label{post_misc_regs_twoqual}" _n
    file write `fh' "\end{table}" _n
    file write `fh' "% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%" _n
    file close `fh'
    type "$OUT/post_misc_regs_examqual_wrapper.tex"

* Close the log
    log close
