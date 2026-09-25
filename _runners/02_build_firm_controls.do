********************************************************************************
* Builds fiscal-year filing dates and the firm-level control panel from Form ADV.
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
    global pin_filing_tie = 1

* Move to the data folder and open the log
    cd "$PKG/2023"
    log using "$PKG/logs/build/02_build_firm_controls.log", replace text
    display "STATA_VERSION = " c(stata_version)
    which reghdfe

* Build the fiscal-year filing dates; stop on error
    display "=== build_fiscal_year_filings ==="
    capture noisily do ../BuildPanels/build_fiscal_year_filings.do
    local stage_rc = _rc
    display "RC_BUILD_FISCAL_YEAR_FILINGS = " `stage_rc'
    if `stage_rc' != 0 exit `stage_rc'

* Build the firm control panel; stop on error
    display "=== build_firm_controls_data ==="
    capture noisily do ../BuildPanels/build_firm_controls_data.do
    local stage_rc = _rc
    display "RC_BUILD_FIRM_CONTROLS_DATA = " `stage_rc'
    if `stage_rc' != 0 exit `stage_rc'

* Report the row count of each output dataset
    foreach f in firm_adv_controls businesslines adv_filing_dates {
        use data/output/`f', clear
        display "ROWS `f' = " _N
    }
    display "RUN_FINISHED=1"
    log close
