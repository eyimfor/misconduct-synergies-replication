********************************************************************************
* Builds the labor-outcome samples and Table A.8 (labor-market outcomes after the merger),
* then checks that the target and acquirer samples equal regressionbrokerstarget and
* regressionbrokersacq row for row.
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
    log using "$PKG/logs/17_labor_outcomes.log", replace text name(labor)
    display "STATA_VERSION = " c(stata_version)

* Run the labor-outcome rule fixture
    capture noisily do ../CreateTables/labor_outcomes_fixture.do
    local labor_fixture_rc = _rc
    display "RC_LABOR_FIXTURE = " `labor_fixture_rc'
    if `labor_fixture_rc' exit `labor_fixture_rc'

* Build the labor-outcome samples and the table
    capture noisily do ../CreateTables/labor_outcomes_table.do
    local labor_producer_rc = _rc
    display "RC_LABOR_PRODUCER = " `labor_producer_rc'
    if `labor_producer_rc' exit `labor_producer_rc'

* Check the target sample equals regressionbrokerstarget row for row
    capture noisily {
        use data/output/regressionbrokerstarget, clear
        local labor_target_n = _N
        ds
        local labor_target_vars `r(varlist)'
        use data/output/labor_outcomes_target, clear
        confirm variable labor_source_row
        isid labor_source_row
        assert _N == `labor_target_n'
        sort labor_source_row
        assert labor_source_row == _n
        cf `labor_target_vars' using data/output/regressionbrokerstarget, all
        display "LABOR_TARGET_ROWS = " _N
        display "LABOR_TARGET_SAVED_SAMPLE_EXACT=1"
    }
    local labor_target_rc = _rc
    display "RC_LABOR_TARGET_SAMPLE_EQUAL = " `labor_target_rc'
    if `labor_target_rc' exit `labor_target_rc'

* Check the acquirer sample equals regressionbrokersacq row for row
    capture noisily {
        use data/output/regressionbrokersacq, clear
        local labor_acquirer_n = _N
        ds
        local labor_acquirer_vars `r(varlist)'
        use data/output/labor_outcomes_acquirer, clear
        confirm variable labor_source_row
        isid labor_source_row
        assert _N == `labor_acquirer_n'
        sort labor_source_row
        assert labor_source_row == _n
        cf `labor_acquirer_vars' using data/output/regressionbrokersacq, all
        display "LABOR_ACQUIRER_ROWS = " _N
        display "LABOR_ACQUIRER_SAVED_SAMPLE_EXACT=1"
    }
    local labor_acquirer_rc = _rc
    display "RC_LABOR_ACQUIRER_SAMPLE_EQUAL = " `labor_acquirer_rc'
    if `labor_acquirer_rc' exit `labor_acquirer_rc'

* Check the table and both samples exist
    capture noisily {
        confirm file tables/separationmerger.tex
        confirm file data/output/labor_outcomes_target.dta
        confirm file data/output/labor_outcomes_acquirer.dta
    }
    local labor_outputs_rc = _rc
    display "RC_LABOR_OUTPUTS = " `labor_outputs_rc'
    if `labor_outputs_rc' exit `labor_outputs_rc'

* Mark the run finished and close the log
    display "RUN_FINISHED=1"
    log close labor
