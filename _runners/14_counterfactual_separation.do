********************************************************************************
* Builds the no-separation counterfactual panel and produces Figure 6
* (Figure6_PureSeparation_DiD.png).
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
    log using "$PKG/logs/14_counterfactual_separation.log", replace text
    display "STATA_VERSION = " c(stata_version)
    which reghdfe

* Build the no-separation counterfactual panel
    display "=== counterfactual_no_separation.do ==="
    capture noisily do ../CreateFigures/counterfactual_no_separation.do
    display "RC_COUNTERFACTUAL_NO_SEPARATION = " _rc

* Produce Figure 6
    display "=== misconduct_drop_counterfactual.do ==="
    capture noisily do ../CreateFigures/misconduct_drop_counterfactual.do
    display "RC_MISCONDUCT_DROP_COUNTERFACTUAL = " _rc

* Report the panel's row count and whether the figure exists
    foreach f in fig6_adviser_panel {
        capture use data/output/`f', clear
        if _rc == 0 display "ROWS `f' = " _N
        else        display "ROWS `f' = MISSING"
    }
    capture confirm file figures/Figure6_PureSeparation_DiD.png
    display "PNG Figure6_PureSeparation_DiD.png rc = " _rc
    display "RUN_FINISHED=1"
    log close
