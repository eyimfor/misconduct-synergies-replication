********************************************************************************
* _settings.do : shared paths and helper programs for the broker-qualification
* robustness of Appendix Table A.7. All writes go to $WD (this folder) only.
********************************************************************************
clear all
set more off
* varabbrev stays ON: the pipeline code relies on abbreviations such as _m for _merge and dollar_aum for dollar_aumc
set linesize 120


********************************************************************************
* Paths
********************************************************************************

* Load the package config, which sets $PKG and the three ado paths. _config.do is
* looked for one and two levels above this folder; PKG in the environment wins
    local CFG ""
    local ENVPKG : environment PKG
    foreach c in "`ENVPKG'/_config.do" "../_config.do" "../../_config.do" {
        if "`CFG'" == "" {
            cap confirm file "`c'"
            if !_rc local CFG "`c'"
        }
    }
    if "`CFG'" == "" {
        display as error "Cannot find _config.do: set the PKG environment variable."
        exit 601
    }
    do "`CFG'"

* Read-only inputs
    global ROOT "$PKG"
    global SRC  "$ROOT/2023/data"                     // read-only data built by the pipeline
    global RAW  "$ROOT/SecIAPD/output"                   // read-only scrape extracts
    global PAPER  "$ROOT/manuscript"                    // read-only manuscript copy

* This folder is wherever its do-files are launched from
* (<PKG>/CreateTables/BrokerRegistrationRobustness)
    global WD   "`c(pwd)'"
    cap confirm file "$WD/_settings.do"
    if _rc {
        display as error "Run the BrokerRegistrationRobustness do-files from that folder."
        exit 601
    }

* Output folders under this folder
    global DATA "$WD/data"
    global LOGS "$WD/logs"
    global OUT  "$WD"
    cap mkdir "$DATA"
    cap mkdir "$LOGS"
    cd "$WD"

* esttab options used by the Table IX code (pseudo_real_merger_test.do)
    global ESTTAB_OPTS `"label star(* 0.10 ** 0.05 *** 0.01) se(3) b(3) order(interaction treated post) ar2 noomitted interaction(" $\times$ ") style(tex) compress nomtitles fragment noconst"'


********************************************************************************
* label_baseline: variable labels as in the Table IX code
********************************************************************************

* Define label_baseline
    cap program drop label_baseline
    program define label_baseline
        la var interaction "Merged X Post"
        la var treated "Merged"
        la var post "Post"
        la var ln_aum_std "Ln(Assets under management)"
        la var ln_age_z "Ln(Firm Age)"
        la var ln_employees_std "Ln(Number of employees)"
        la var both_retailc "Retail clients"
    end


********************************************************************************
* run_baseline_regs: the four Table IX columns, stored as <prefix>1..4
********************************************************************************

* Define run_baseline_regs
    cap program drop run_baseline_regs
    program define run_baseline_regs
        syntax , [prefix(string)]
        if "`prefix'" == "" local prefix m

        * Fixed effects, clustering and the two control sets
        local fe1 year_aum
        local clustervar cohort
        local controls  interaction treated post
        local controls2 interaction treated post both_retailc ln_aum_std ln_age_z ln_employees_std

        * Estimate and store the four columns
        eststo `prefix'1: reghdfe fraction_bad_a_flow `controls',  absorb(`fe1') vce(cluster `clustervar')
        eststo `prefix'2: reghdfe fraction_bad_a_flow `controls2', absorb(`fe1') vce(cluster `clustervar')
        eststo `prefix'3: reghdfe fraction_bad_e_flow `controls',  absorb(`fe1') vce(cluster `clustervar')
        eststo `prefix'4: reghdfe fraction_bad_e_flow `controls2', absorb(`fe1') vce(cluster `clustervar')
    end


********************************************************************************
* post_estimates: append coefficient-level results of stored estimates to an
* open postfile handle. Caller opens the handle with:
*   postfile H str40 sample str12 model int col str32 var double b se t p ///
*       str5 stars long N int nclust double r2_a r2 df_r using ...
********************************************************************************

* Define post_estimates
    cap program drop post_estimates
    program define post_estimates
        syntax , sample(string) models(string) handle(string)
        local col = 0
        foreach m of local models {
            * Restore each model and read its fit statistics
            local ++col
            qui est restore `m'
            local N = e(N)
            local nclust = e(N_clust)
            local r2a = e(r2_a)
            local r2 = e(r2)
            local dfr = e(df_r)

            * Post each coefficient with its standard error, t, p and stars
            local vars : colnames e(b)
            foreach v of local vars {
                if "`v'" == "_cons" continue
                local b = _b[`v']
                local se = _se[`v']
                local t = `b'/`se'
                local p = 2*ttail(`dfr', abs(`t'))
                local stars = cond(`p' < 0.01, "***", cond(`p' < 0.05, "**", cond(`p' < 0.10, "*", "")))
                post `handle' ("`sample'") ("`m'") (`col') ("`v'") (`b') (`se') (`t') (`p') ("`stars'") (`N') (`nclust') (`r2a') (`r2') (`dfr')
            }

            * Post N and adjusted R-squared as their own rows
            post `handle' ("`sample'") ("`m'") (`col') ("N") (`N') (.) (.) (.) ("") (`N') (`nclust') (`r2a') (`r2') (`dfr')
            post `handle' ("`sample'") ("`m'") (`col') ("r2_a") (`r2a') (.) (.) (.) ("") (`N') (`nclust') (`r2a') (`r2') (`dfr')
        }
    end


********************************************************************************
* parse_esttab_tex: read an esttab fragment (b(3) se(3) layout) into a dataset
*   variables: str32 var, int col, double b, se, str5 stars
*   (N and r2_a are stored in b). Row labels are mapped back to variable names.
********************************************************************************

* Define parse_esttab_tex
    cap program drop parse_esttab_tex
    program define parse_esttab_tex
        syntax , file(string) saving(string)

        * Open a postfile for the parsed cells and the fragment for reading
        tempname fh P
        tempfile raw
        postfile `P' str32 var int col double b double se str5 stars using "`raw'", replace
        file open `fh' using "`file'", read text
        file read `fh' line
        local lastlabel ""
        local expect_se = 0

        * Read the fragment line by line
        while r(eof) == 0 {
            local l : subinstr local line "\\" "", all
            local l : subinstr local l "`=char(9)'" " ", all

            * Split on & keeping empty cells (gettoken would drop blank cells)
            local ncell = 0
            local rest `"`l'"'
            local more = 1
            while `more' {
                local pos = strpos(`"`rest'"', "&")
                local ++ncell
                if `pos' == 0 {
                    local c`ncell' = strtrim(`"`rest'"')
                    local more = 0
                }
                else {
                    local c`ncell' = strtrim(substr(`"`rest'"', 1, `pos' - 1))
                    local rest = substr(`"`rest'"', `pos' + 1, .)
                }
            }
            if `ncell' == 1 & `"`c1'"' == "" local ncell = 0

            * Parse table rows only (skip \multicolumn and \cmidrule lines)
            if `ncell' >= 2 & !strpos(`"`l'"', "multicolumn") & !strpos(`"`l'"', "cmidrule") {
                local lab `"`c1'"'
                if `"`lab'"' != "" {
                    * A labelled row: map the row label back to its variable name
                    local var ""
                    if `"`lab'"' == "Merged X Post" local var interaction
                    if `"`lab'"' == "Merged" local var treated
                    if `"`lab'"' == "Post" local var post
                    if `"`lab'"' == "Retail clients" local var both_retailc
                    if `"`lab'"' == "Ln(Assets under management)" local var ln_aum_std
                    if `"`lab'"' == "Ln(Firm Age)" local var ln_age_z
                    if `"`lab'"' == "Ln(Number of employees)" local var ln_employees_std
                    if `"`lab'"' == "Observations" local var N
                    if strpos(`"`lab'"', "Adjusted") local var r2_a

                    * Post each column's value and stars; expect a standard-error row next
                    * unless the row is N or r2_a
                    if "`var'" != "" {
                        forvalues k = 2/`ncell' {
                            local cell `"`c`k''"'
                            local stars ""
                            if regexm(`"`cell'"', "sym\{(\*+)\}") local stars = regexs(1)
                            local cell = regexr(`"`cell'"', "\\sym\{\**\}", "")
                            local cell : subinstr local cell "`=char(92)'" "", all
                            local cell : subinstr local cell "," "", all
                            local cell = strtrim(`"`cell'"')
                            local val = real(`"`cell'"')
                            if `val' != . post `P' ("`var'") (`=`k'-1') (`val') (.) ("`stars'")
                        }
                        local lastlabel "`var'"
                        local expect_se = inlist("`var'", "N", "r2_a") == 0
                    }
                    else {
                        local expect_se = 0
                    }
                }
                else if `expect_se' == 1 {
                    * An unlabelled row after a coefficient row: post its standard errors
                    forvalues k = 2/`ncell' {
                        local cell `"`c`k''"'
                        local cell : subinstr local cell "(" "", all
                        local cell : subinstr local cell ")" "", all
                        local cell = strtrim(`"`cell'"')
                        local val = real(`"`cell'"')
                        if `val' != . post `P' ("`lastlabel'") (`=`k'-1') (.) (`val') ("")
                    }
                    local expect_se = 0
                }
            }
            file read `fh' line
        }
        file close `fh'
        postclose `P'

        * Collapse to one row per variable and column, and save
        preserve
            use "`raw'", clear
            collapse (max) b se (firstnm) stars, by(var col)
            save "`saving'", replace
        restore
    end


********************************************************************************
* compare_to_target: compare stored estimates (models) with a parsed target
*   file and append rows to an open postfile handle with structure
*   str40 target str12 model int col str32 var str8 stat double target_value ///
*   double reproduced double difference str5 result
********************************************************************************

* Define compare_to_target
    cap program drop compare_to_target
    program define compare_to_target
        syntax , target(string) targetfile(string) models(string) handle(string)
        preserve
            use "`targetfile'", clear
            local nrows = _N
            forvalues i = 1/`nrows' {
                * Read the target row and restore the model for its column
                local var = var[`i']
                local col = col[`i']
                local tb = b[`i']
                local tse = se[`i']
                local tstars = stars[`i']
                local m : word `col' of `models'
                qui est restore `m'

                * N must match exactly
                if "`var'" == "N" {
                    local rep = e(N)
                    local d = `rep' - `tb'
                    post `handle' ("`target'") ("`m'") (`col') ("`var'") ("N") (`tb') (`rep') (`d') (cond(`d' == 0, "PASS", "FAIL"))
                }
                else if "`var'" == "r2_a" {
                    * Adjusted R-squared must match to 3 decimals
                    local rep = round(e(r2_a), 0.001)
                    local d = `rep' - `tb'
                    post `handle' ("`target'") ("`m'") (`col') ("`var'") ("r2_a") (`tb') (`rep') (`d') (cond(abs(`d') < 1e-6, "PASS", "FAIL"))
                }
                else {
                    * Coefficients: b and se to 3 decimals, and the same stars
                    local vars : colnames e(b)
                    local found : list var in vars
                    if `found' == 0 {
                        post `handle' ("`target'") ("`m'") (`col') ("`var'") ("b") (`tb') (.) (.) ("FAIL")
                        continue
                    }
                    local rb = round(_b[`var'], 0.001)
                    local rse = round(_se[`var'], 0.001)
                    local t = _b[`var']/_se[`var']
                    local p = 2*ttail(e(df_r), abs(`t'))
                    local rstars = cond(`p' < 0.01, "***", cond(`p' < 0.05, "**", cond(`p' < 0.10, "*", "")))
                    local d = `rb' - `tb'
                    post `handle' ("`target'") ("`m'") (`col') ("`var'") ("b") (`tb') (`rb') (`d') (cond(abs(`d') < 1e-6, "PASS", "FAIL"))
                    local d = `rse' - `tse'
                    post `handle' ("`target'") ("`m'") (`col') ("`var'") ("se") (`tse') (`rse') (`d') (cond(abs(`d') < 1e-6, "PASS", "FAIL"))
                    local nts = length("`tstars'")
                    local nrs = length("`rstars'")
                    post `handle' ("`target'") ("`m'") (`col') ("`var'") ("stars") (`nts') (`nrs') (`nrs' - `nts') (cond("`tstars'" == "`rstars'", "PASS", "FAIL"))
                }
            }
        restore
    end
