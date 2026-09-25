********************************************************************************
* Builds the merger sample and the target, acquirer, and target-acquirer
* summary statistics.
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

* Keep the lowest acquirer CRD when a target has two acquirers in the same year
    global pin_merger_tie = 1

* Move to the data folder and open the log
    cd "$PKG/2023"
    log using "$PKG/logs/05_merger_sample.log", replace text
    display "STATA_VERSION = " c(stata_version)
    which winsor2
    which rangestat

* Build the merger-pair list
    display "=== merger_list.do ==="
    do "$PKG/_rules/merger_list.do" load 0
    display "ROWS mergers2021and2023 = " _N
    quietly count if mergeryear >= 2011 & mergeryear <= 2020
    display "ROWS mergers2021and2023 in 2011-2020 = " r(N)

* Build the target statistics
    display "=== stats_target_firm.do ==="
    capture noisily do ../CreateSample/stats_target_firm.do
    display "RC_STATS_TARGET_FIRM = " _rc

* Build the acquirer statistics
    display "=== stats_acquirer_firm.do ==="
    capture noisily do ../CreateSample/stats_acquirer_firm.do
    display "RC_STATS_ACQUIRER_FIRM = " _rc

* Build the target-acquirer statistics
    display "=== stats_target_acquirer_firm.do ==="
    capture noisily do ../CreateSample/stats_target_acquirer_firm.do
    display "RC_STATS_TARGET_ACQUIRER_FIRM = " _rc

* Build the merger summary statistics
    display "=== merger_summary_stats.do ==="
    capture noisily do ../CreateSample/merger_summary_stats.do
    display "RC_MERGER_SUMMARY_STATS = " _rc

* Report row counts of the output datasets
    foreach f in mergers2021and2023 mergers target_stats acquirer_stats both acquirer_stats_b target_acquirer_stats merger_sample {
        capture use data/output/`f', clear
        if _rc == 0 display "ROWS `f' = " _N
        else        display "ROWS `f' = MISSING"
    }
    display "RUN_FINISHED=1"
    log close
