********************************************************************************
* Builds the disclosure counts behind Figure 1.
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
    log using "$PKG/logs/08_figure_disclosures.log", replace text
    display "STATA_VERSION = " c(stata_version)
    which reghdfe

* Run figure_disclosures.do and record its return code
    display "=== figure_disclosures.do ==="
    capture noisily do ../CreateFigures/figure_disclosures.do
    display "RC_FIGURE_DISCLOSURES = " _rc

* Report the row count of each output dataset
    foreach f in finestargetacquirer {
        capture use data/output/`f', clear
        if _rc == 0 display "ROWS `f' = " _N
        else        display "ROWS `f' = MISSING"
    }

* Mark the run finished and close the log
    display "RUN_FINISHED=1"
    log close
