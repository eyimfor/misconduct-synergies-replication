********************************************************************************
* Runs separations_target.do and separations_acquirer.do: Table X (Panels A and B)
* and Figure 5 (Panels A and B).
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
    log using "$PKG/logs/12_separations.log", replace text

* Run the target and acquirer separation producers and record their return codes
    display "=== separations_target.do ==="
    capture noisily do ../CreateTables/separations_target.do
    display "RC_SEPARATIONS_TARGET = " _rc
    display "=== separations_acquirer.do ==="
    capture noisily do ../CreateTables/separations_acquirer.do
    display "RC_SEPARATIONS_ACQUIRER = " _rc

* Report the row count of each output dataset, or MISSING
    foreach f in temp_one2 target_employeescs2 separation_all_panel2 regressionbrokerstarget2 regressionbrokerstarget separation_acq_panel regressionbrokersacq {
        capture use data/output/`f', clear
        if _rc == 0 display "ROWS `f' = " _N
        else        display "ROWS `f' = MISSING"
    }
    display "RUN_FINISHED=1"
    log close
