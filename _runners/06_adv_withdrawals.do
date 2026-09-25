********************************************************************************
* Builds ADV withdrawal failures and the firm-closure outcome for Table XII,
* Panel B.
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
    log using "$PKG/logs/06_adv_withdrawals.log", replace text

* Build the withdrawal failures and the firm-closure outcome, recording return codes
    display "=== build_adv_withdrawal_failures.do ==="
    capture noisily do ../CreateTables/build_adv_withdrawal_failures.do
    display "RC_BUILD_ADV_WITHDRAWAL_FAILURES = " _rc
    display "=== firm_closure.do ==="
    capture noisily do ../CreateTables/firm_closure.do
    display "RC_FIRM_CLOSURE = " _rc

* Report the row count of each output dataset, or MISSING
    foreach f in merger_targets_raw failed_businesses_sec failed {
        capture use data/output/`f', clear
        if _rc == 0 display "ROWS `f' = " _N
        else        display "ROWS `f' = MISSING"
    }
    display "RUN_FINISHED=1"
    log close
