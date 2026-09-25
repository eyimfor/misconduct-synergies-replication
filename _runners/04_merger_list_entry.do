********************************************************************************
* Reads the merger list, keeps mergers from 2011 to 2020 and the earliest merger
* per target, and saves new_mergers_entry.dta. merger_summary_stats.do (runner 05)
* narrows it to Table I's 485.
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
    log using "$PKG/logs/04_merger_list_entry.log", replace text
    display "STATA_VERSION = " c(stata_version)

* Prepare the merger list; stop with its return code if it fails
    capture noisily do "$PKG/_rules/merger_list.do" prepare 0
    local entry_rc = _rc
    display "RC_ENTRY = " `entry_rc'
    if `entry_rc' != 0 exit `entry_rc'

* Confirm the entry file exists and report its row count
    confirm file data/input/new_mergers_entry.dta
    use data/input/new_mergers_entry.dta, clear
    display "ROWS new_mergers_entry = " _N
    display "RUN_FINISHED=1"
    log close
