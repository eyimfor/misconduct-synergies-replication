********************************************************************************
* Runs the matching estimation within state and a one-year window (Table VI).
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
    log using "$PKG/logs/11_matching_time_window.log", replace text
    display "STATA_VERSION = " c(stata_version)
    which reghdfe

* Run the time-window matching estimation and record its return code
    display "=== matching_time_window.do ==="
    capture noisily do ../CreateTables/matching_time_window.do
    display "RC_MATCHING_TIME_WINDOW = " _rc

* Report the row count of each output dataset, or MISSING
    foreach f in firmyear_employeestate merger_pairs_timewin temp_four_timewin matching_frame_tw temp_six_timewin matching_frame_timewin {
        capture use data/output/`f', clear
        if _rc == 0 display "ROWS `f' = " _N
        else        display "ROWS `f' = MISSING"
    }
    display "RUN_FINISHED=1"
    log close
