********************************************************************************
* Runs the post-merger misconduct regressions for real and pseudo mergers and
* the test comparing them, which writes post_misc_regs.tex (Table IX).
********************************************************************************
clear all
set more off
set linesize 200
set processors 4

* Load the package config, which sets $PKG and the ado paths. Runners are launched
* from <PKG>/_runners, so ../_config.do is at the package root; PKG in the
* environment is the fallback for any other launch point.
    local CFG "../_config.do"
    cap confirm file "`CFG'"
    if _rc {
        local ENVPKG : environment PKG
        local CFG "`ENVPKG'/_config.do"
        cap confirm file "`CFG'"
        if _rc {
            display as error "Cannot find _config.do: run from <PKG>/_runners, or set PKG."
            exit 601
        }
    }
    do "`CFG'"

* Move to the data folder and open the log
    cd "$PKG/2023"
    log using "$PKG/logs/13_post_merger_misconduct.log", replace text
    display "STATA_VERSION = " c(stata_version)
    which reghdfe

* Run the real-merger regressions
    display "=== post_merger_misconduct_real.do ==="
    capture noisily do ../CreateTables/post_merger_misconduct_real.do
    display "RC_POST_MERGER_MISCONDUCT_REAL = " _rc

* Run the pseudo-merger regressions
    display "=== post_merger_misconduct_pseudo.do ==="
    capture noisily do ../CreateTables/post_merger_misconduct_pseudo.do
    display "RC_POST_MERGER_MISCONDUCT_PSEUDO = " _rc

* post_merger_misconduct_real.do and _pseudo.do write the combined-firm panels to
* data/output_robust; pseudo_real_merger_test.do reads them from data/output, so
* copy them there
    display "=== copy the combined-firm panels to data/output ==="
    local copy_rc = 0
    foreach f in postmergercombinedfirm postmergercombinedfirmcf {
        capture noisily copy "data/output_robust/`f'.dta" "data/output/`f'.dta", replace
        if _rc local copy_rc = _rc
    }
    display "RC_COPY_PANELS = " `copy_rc'
    if `copy_rc' != 0 exit `copy_rc'

* Run the test comparing real and pseudo mergers
    display "=== pseudo_real_merger_test.do ==="
    capture noisily do ../CreateTables/pseudo_real_merger_test.do
    display "RC_PSEUDO_REAL_MERGER_TEST = " _rc

* Report row counts of the output datasets and whether the table was written
    foreach f in mergerreal event_panel_real postmergercombinedfirm mergercf event_panel_pseudo postmergercombinedfirmcf {
        capture use data/output_robust/`f', clear
        if _rc == 0 display "ROWS output_robust/`f' = " _N
        else        display "ROWS output_robust/`f' = MISSING"
    }
    foreach f in mergercf postmergercombinedfirm postmergercombinedfirmcf adviser_event_panel {
        capture use data/output/`f', clear
        if _rc == 0 display "ROWS `f' = " _N
        else        display "ROWS `f' = MISSING"
    }
    capture confirm file tables/post_misc_regs.tex
    display "TEX post_misc_regs.tex rc = " _rc
    display "RUN_FINISHED=1"
    log close
