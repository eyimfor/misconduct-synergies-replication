********************************************************************************
* Builds firm-level misconduct measures, AUM per employee (Table XII, Panel A),
* annual settlements (Figure A.1) and the M&A employee sample (Table A.10).
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
    log using "$PKG/logs/build/03_build_firm_misconduct.log", replace text
    display "STATA_VERSION = " c(stata_version)
    which reghdfe

* Build the firm-level misconduct measures
    display "=== firm_misconduct_levels.do ==="
    capture noisily do ../BuildPanels/firm_misconduct_levels.do
    local stage_rc = _rc
    display "RC_FIRM_MISCONDUCT_LEVELS = " `stage_rc'
    if `stage_rc' != 0 exit `stage_rc'

* Build AUM per employee
    display "=== aum_per_employee.do ==="
    capture noisily do ../CreateTables/aum_per_employee.do
    local stage_rc = _rc
    display "RC_AUM_PER_EMPLOYEE = " `stage_rc'
    if `stage_rc' != 0 exit `stage_rc'

* Build annual settlements
    display "=== fines_per_year.do ==="
    capture noisily do ../CreateFigures/fines_per_year.do
    local stage_rc = _rc
    display "RC_FINES_PER_YEAR = " `stage_rc'
    if `stage_rc' != 0 exit `stage_rc'

* Build the M&A employee sample
    display "=== ma_employee_misconduct.do ==="
    capture noisily do ../CreateTables/ma_employee_misconduct.do
    local stage_rc = _rc
    display "RC_MA_EMPLOYEE_MISCONDUCT = " `stage_rc'
    if `stage_rc' != 0 exit `stage_rc'

* Report row counts of the output datasets
    foreach f in firm_year_panel all_regression rr_disclosures_yearly ma_brokers crds_ma_employees {
        capture use data/output/`f', clear
        if _rc == 0 display "ROWS `f' = " _N
        else        display "ROWS `f' = MISSING"
    }
    display "RUN_FINISHED=1"
    log close
