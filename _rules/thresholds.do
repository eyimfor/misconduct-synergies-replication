********************************************************************************
* Sample thresholds applied at the merger-event unit.
* Usage: twins "keys" realvar | candidates "event keys" real_match [savepath] |
*        frequent firm year treated.
********************************************************************************
args action key measure option

* twins: keep keys where the real pair and its pseudo pair both appear in the
* same event year (Table XI)
if "`action'" == "twins" {
    bys `key': egen obs = nvals(`measure')
    keep if obs == 2
    exit
}

* candidates: drop events with no pseudo (counterfactual) matches and optionally
* save the result (Tables V, VI, A.4; Figures 2, 3)
if "`action'" == "candidates" {
    tempvar has_pseudo
    bys `key': egen byte `has_pseudo' = max(`measure' == 0)
    keep if `has_pseudo' == 1
    drop `has_pseudo'
    if "`option'" != "" save `option', replace
    exit
}

* frequent: flag acquisitions that follow the acquirer's first acquisition in
* the sample (Table A.6)
if "`action'" == "frequent" {
    bys `key': egen min_acquiredyear_real = min(`measure') if `option' == 1
    bys `key': egen min_acquiredyear = min(min_acquiredyear_real)
    gen pastacquirer = (`measure' > min_acquiredyear)
    replace pastacquirer = 0 if `option' == 0
    exit
}

* Unknown action
exit 198
