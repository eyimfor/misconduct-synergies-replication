********************************************************************************
* Runs the regressions predicting targets and acquirers (Tables III and IV).
* The two *_regression_build files build the samples; the two *_industry_build
* files run last and write tables/target_regression.tex and
* tables/acquirer_regression.tex.
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
    log using "$PKG/logs/07_target_acquirer_regressions.log", replace text
    display "STATA_VERSION = " c(stata_version)
    which reghdfe

* Build the target regression sample
    display "=== target_regression_build.do ==="
    capture noisily do ../CreateTables/target_regression_build.do
    display "RC_TARGET_REGRESSION_BUILD = " _rc

* Build the acquirer regression sample
    display "=== acquirer_regression_build.do ==="
    capture noisily do ../CreateTables/acquirer_regression_build.do
    display "RC_ACQUIRER_REGRESSION_BUILD = " _rc

* Write the target regression table
    display "=== target_regression_table.do ==="
    capture noisily do ../CreateTables/target_regression_table.do
    display "RC_TARGET_REGRESSION_TABLE = " _rc

* Write the acquirer regression table
    display "=== acquirer_regression_table.do ==="
    capture noisily do ../CreateTables/acquirer_regression_table.do
    display "RC_ACQUIRER_REGRESSION_TABLE = " _rc

* Report the row count of each output dataset
    foreach f in targetfirms target_regression target_regression_sample acquiringfirms acquirer_regression acquirer_regression_sample {
        capture use data/output/`f', clear
        if _rc == 0 display "ROWS `f' = " _N
        else        display "ROWS `f' = MISSING"
    }
    display "RUN_FINISHED=1"
    log close
