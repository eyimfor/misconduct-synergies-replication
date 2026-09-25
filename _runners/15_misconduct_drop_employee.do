********************************************************************************
* Runs the employee-level misconduct-decline regressions (Table XI).
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
    log using "$PKG/logs/15_misconduct_drop_employee.log", replace text
    display "STATA_VERSION = " c(stata_version)
    which reghdfe

* Run misconduct_drop_employee.do and record its return code
    display "=== misconduct_drop_employee.do ==="
    capture noisily do ../CreateTables/misconduct_drop_employee.do
    display "RC_MISCONDUCT_DROP_EMPLOYEE = " _rc

* Report the row count of each output dataset
    foreach f in separation_all_counterfactual regressioncounterfactual {
        capture use data/output/`f', clear
        if _rc == 0 display "ROWS `f' = " _N
        else        display "ROWS `f' = MISSING"
    }

* Check that the table file exists
    capture confirm file tables/drop_disclosures.tex
    display "TEX drop_disclosures.tex rc = " _rc

* Mark the run finished and close the log
    display "RUN_FINISHED=1"
    log close
