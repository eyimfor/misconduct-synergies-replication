********************************************************************************
* Figure A.3 Panel B estimation: disclosure measures that exclude employment
* separations after allegations, and the event dated by announcement and by
* closing year. Writes the coefficients to results/estimates.dta.
********************************************************************************
clear all
set more off
set processors 2
set linesize 180

* Read the working-copy root, passed as the first argument
    global EXTROOT "`1'"
    if "$EXTROOT"=="" exit 198

* Point the ado paths at the working copy and open the log
    sysdir set PLUS "$EXTROOT/environment/ado_plus"
    sysdir set PERSONAL "$EXTROOT/environment/ado_personal"
    adopath ++ "$EXTROOT/environment/ado_shim"
    cd "$EXTROOT/2023"
    log using "$EXTROOT/logs/panelB_result.log", text replace
    display "Figure A.3 Panel B estimation"

* Open the results file
    tempname result_handle
    global EXTRESULT `result_handle'
    postfile `result_handle' str20 family str40 model str40 term double b se df p lo95 hi95 N clusters using "$EXTROOT/results/estimates.dta", replace

* save_term posts one coefficient with its standard error, p-value and 95% interval
    capture program drop save_term
    program define save_term
        args family model term
        scalar bx = _b[`term']
        scalar sex = _se[`term']
        scalar px = 2*ttail(e(df_r),abs(bx/sex))
        scalar crit = invttail(e(df_r),.025)
        post $EXTRESULT ("`family'") ("`model'") ("`term'") (bx) (sex) (e(df_r)) (px) (bx-crit*sex) (bx+crit*sex) (e(N)) (e(N_clust))
    end

* Disclosure measures that exclude employment separations after allegations,
* winsorized at 1 and 99 percent
    use "$EXTROOT/results/category_panel.dta", clear
    gen double tp = treated*post
    foreach y in all_nosep_three ems_nosep_three {
        assert !missing(`y')
        clonevar raw_`y' = `y'
        winsor2 `y', cuts(1 99) replace
        quietly count if raw_`y' != `y'
        display "WINSORIZED_`y'=" r(N)
        reghdfe `y' tp, absorb(unit pair_time) vce(cluster cohort)
        save_term category `y' tp
    }
    display "CATEGORY_FINISHED=1"

* Event dated by the announcement year and by the closing year, on the same rows
    use "$EXTROOT/results/timing_panel.dta", clear
    keep if timing_sample==1
    gen double tp_announce = treated*post
    gen double tp_closing = treated*post_close
    foreach measure in all ems {
        if "`measure'"=="all" local y fraction_bad_a_flow
        if "`measure'"=="ems" local y fraction_bad_e_flow
        foreach clock in announce closing {
            reghdfe `y' tp_`clock', absorb(unit pair_time) vce(cluster cohort)
            save_term timing `measure'_`clock' tp_`clock'
        }
    }
    display "TIMING_FINISHED=1"

* Close the results file and the log
    postclose `result_handle'
    display "RUN_FINISHED=1"
    log close
    exit, clear
