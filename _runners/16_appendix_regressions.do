********************************************************************************
* Runs appendix_industry_controls.do: Tables A.2, A.3, A.4 and A.6.
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
    log using "$PKG/logs/16_appendix_regressions.log", replace text
    display "STATA_VERSION = " c(stata_version)
    which reghdfe

* Report which inputs are present
    foreach f in target_regression acquirer_regression_sample acquirer_regression target_regression_sample matching_frame_full firm_adv_controls adviser_event_panel {
        capture confirm file data/output/`f'.dta
        display "INPUT `f' rc = " _rc
    }

* Run the appendix regressions
    display "=== appendix_industry_controls.do ==="
    capture noisily do ../CreateTables/appendix_industry_controls.do
    display "RC_APPENDIX_INDUSTRY_CONTROLS = " _rc

* Report which tables were written
    foreach t in target_regressionind acquirer_regressionind matching_regressionind post_misc_regsfa {
        capture confirm file tables/`t'.tex
        display "TEX `t'.tex rc = " _rc
    }
    display "RUN_FINISHED=1"
    log close
