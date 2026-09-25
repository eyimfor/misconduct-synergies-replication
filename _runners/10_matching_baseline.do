********************************************************************************
* Runs the baseline matching-on-misconduct estimation (Table V).
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
    log using "$PKG/logs/10_matching_baseline.log", replace text
    display "STATA_VERSION = " c(stata_version)
    which reghdfe

* Run matching_baseline.do and record its return code
    display "=== matching_baseline.do ==="
    capture noisily do ../CreateTables/matching_baseline.do
    display "RC_MATCHING_BASELINE = " _rc

* Report the row count of each output dataset
    foreach f in merger_data_small_two25 merger_pairs temp_four matching_frame temp_six matching_frame_full {
        capture use data/output/`f', clear
        if _rc == 0 display "ROWS `f' = " _N
        else        display "ROWS `f' = MISSING"
    }

* Mark the run finished and close the log
    display "RUN_FINISHED=1"
    log close
