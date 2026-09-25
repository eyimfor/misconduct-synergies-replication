********************************************************************************
* Builds the adviser employment, exam, and disclosure panels from the raw
* registration extracts.
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
    log using "$PKG/logs/build/01_build_adviser_panels.log", replace text

* Build the employment panel
    display "=== build_employment_panel ==="
    capture noisily do ../BuildPanels/build_employment_panel.do
    display "RC_EMPLOYMENT = " _rc

* Build the exam panel
    display "=== build_exam_panel ==="
    capture noisily do ../BuildPanels/build_exam_panel.do
    display "RC_EXAMS = " _rc

* Summarize the exams
    display "=== process_exams ==="
    capture noisily do ../BuildPanels/process_exams.do
    display "RC_EXAM_SUMMARY = " _rc

* Build the disclosure panel
    display "=== build_disclosure_panel ==="
    capture noisily do ../BuildPanels/build_disclosure_panel.do
    display "RC_DISCLOSURES = " _rc

* Mark the run finished and close the log
    display "RUN_FINISHED=1"
    log close
