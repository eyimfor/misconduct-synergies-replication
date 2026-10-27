********************************************************************************
* Master file for the broker-qualification robustness appendix. Re-estimates
* the post-merger difference-in-differences table (Table IX) from the individual
* adviser panels and then by pre-merger qualification group, and writes
* Appendix Table A.8 (post_misc_regs_examqual.tex).
********************************************************************************
clear all
cap log close runall

* Usage and inputs
*   Run from this folder (run_all.sh does so): stata-mp -b do run_all.do
*   Requires: reghdfe, ftools, estout/esttab, winsor2, egenmore (nvals)
*   Read-only inputs: ../../2023/data (built by the pipeline), ../../SecIAPD/output
*   (the scrape extracts) and ../../manuscript/Tables/post_misc_regs.tex (the
*   published Table IX, used as a comparison target)
*   Every output is written inside BrokerRegistrationRobustness/ (data/, logs/, root)

* Check that Stata runs from this folder; no absolute path is needed
    local wd "`c(pwd)'"
    cap confirm file "`wd'/_settings.do"
    if _rc {
        display as error "Run run_all.do from the BrokerRegistrationRobustness folder."
        exit 601
    }

* Open the log and record the Stata environment
    cap mkdir "`wd'/logs"
    log using "`wd'/logs/run_all.log", replace text name(runall)
    di as text "run_all started " c(current_date) " " c(current_time)
    di as text "Stata " c(stata_version) " " c(edition_real) " born " c(born_date) " cores " c(processors)

* 01: re-estimate Table IX from the pipeline's estimation sample and read the targets
    capture noisily do "`wd'/01_replicate_baseline.do"
    local brr_rc = _rc
    display "RC_BRR_01 = " `brr_rc'
    if `brr_rc' != 0 exit `brr_rc'

* 02: rebuild the cells and the estimation sample from the individual panels
    capture noisily do "`wd'/02_rebuild_baseline_outcomes.do"
    local brr_rc = _rc
    display "RC_BRR_02 = " `brr_rc'
    if `brr_rc' != 0 exit `brr_rc'

* 03: fix each adviser's qualification status at t-1; restricted numerators and denominators
    capture noisily do "`wd'/03_build_status_robustness.do"
    local brr_rc = _rc
    display "RC_BRR_03 = " `brr_rc'
    if `brr_rc' != 0 exit `brr_rc'

* 04: estimate by qualification group, with diagnostics and validation checks
    capture noisily do "`wd'/04_estimate_status_robustness.do"
    local brr_rc = _rc
    display "RC_BRR_04 = " `brr_rc'
    if `brr_rc' != 0 exit `brr_rc'

* 05: Appendix Table A.8 in the paper's layout
    capture noisily do "`wd'/05_appendix_exam_table.do"
    local brr_rc = _rc
    display "RC_BRR_05 = " `brr_rc'
    if `brr_rc' != 0 exit `brr_rc'

* Close the log
    di as text "run_all finished " c(current_date) " " c(current_time)
    log close runall
