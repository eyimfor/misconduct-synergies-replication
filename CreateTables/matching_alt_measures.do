********************************************************************************
* Table A.5: the matching regressions of Tables V and VI re-estimated with alternative measures of
* the distance in misconduct between a candidate acquirer and the target, nine measures by four
* columns (all candidate pairs and within state, All and EMS), each with the column (2) controls
* of Tables V and VI. Writes tables/matching_alt_measures.tex in the paper's layout, and
* tables/matching_rank_numbers.txt, the descriptives and coefficients Section III.B quotes.
* Reads matching_sample_full.dta and matching_sample_timewin.dta, the Table V and VI estimation
* samples with the Misconduct Distance Rank, saved by matching_baseline.do and
* matching_time_window.do.
********************************************************************************
clear

* Line-of-business fixed effects, and the column (2) controls of Tables V and VI
    local industry financial_planning port_mgmt_indv_sb port_mgmt_inv_c port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing other
    local c1 retail_clients aum_ratio_z age_ratio_z employee_ratio_z same_state

* The numbers the text quotes, one key=value per line, and the table cells (b, se, p) by row and column
    file open NUM using "tables/matching_rank_numbers.txt", write replace
    matrix ALT = J(9, 12, .)
    matrix NOBS = J(1, 4, .)

* Write one number to the numbers file
    cap program drop put
    program define put
        args key value
        file write NUM "`key'=`value'" _n
    end

* Alternative distance measures, built on an estimation sample that already carries the rank
    cap program drop build_measures
    program define build_measures
        foreach m in a e {

            * Rank of the raw difference in rates within the candidate set, scaled 0-1 like the rank
            gen rawd_`m' = abs(acquirer_misc_`m' - target_misc_`m')
            bys target_crd acquired_year: egen double rkraw_`m' = rank(rawd_`m')
            gen double rawrank_`m' = (rkraw_`m' - 1) / (nset_`m' - 1)

            * The asinh distance standardized, and the raw difference winsorized at the 99th percentile and standardized
            egen adist_`m'_z = std(adist_`m')
            winsor2 rawd_`m', cut(0 99) suffix(_w)
            egen wdist_`m'_z = std(rawd_`m'_w)
        }

        * Firm-level percentile ranks and zero/low/high bins within the acquisition year, one row per firm-year
        foreach side in a t {
            local crd = cond("`side'"=="a", "acquirer_crd", "target_crd")
            local pre = cond("`side'"=="a", "acquirer_misc_", "target_misc_")
            bys acquired_year `crd': gen byte tag_`side' = (_n==1)
            bys acquired_year: egen double n_`side' = total(tag_`side')
            foreach m in a e {
                bys acquired_year: egen double r_`side'`m' = rank(`pre'`m') if tag_`side'
                gen double pcttag_`side'`m' = (r_`side'`m' - 1) / (n_`side' - 1)
                bys acquired_year `crd': egen double pct_`side'`m' = max(pcttag_`side'`m')
                gen double pos_`side'`m' = `pre'`m' if tag_`side' & `pre'`m' > 0
                bys acquired_year: egen double medpos_`side'`m' = median(pos_`side'`m')
                gen byte bin_`side'`m' = cond(`pre'`m'==0, 0, cond(`pre'`m' <= medpos_`side'`m', 1, 2))
            }
        }

        * Pair-level alternatives: percentile-rank distance and interaction, bin distance, status interaction
        foreach m in a e {
            local A = cond("`m'"=="a", "misc_cut_aa", "misc_cut_ae")
            local T = cond("`m'"=="a", "misc_cut_ta", "misc_cut_te")
            gen pA_`m' = pct_a`m'
            gen pT_`m' = pct_t`m'
            gen int_p_`m' = pct_a`m' * pct_t`m'
            gen rdist_`m' = abs(pct_a`m' - pct_t`m')
            gen bdist_`m' = abs(bin_a`m' - bin_t`m')
            gen dA_`m' = `A'
            gen dT_`m' = `T'
            gen int_d_`m' = `A' * `T'
        }
    end


********************************************************************************
* Both samples: descriptives, the Table V and VI coefficients the text quotes, and the alternatives
********************************************************************************
foreach frame in matching_sample_full matching_sample_timewin {
    local tag = cond("`frame'"=="matching_sample_full", "full", "tw")
    local coloff = cond("`tag'"=="full", 0, 2)

    * Load the estimation sample and build the alternative measures
        use data/output/`frame', clear
        build_measures

    * Candidate-set size, the base merger rate, and the rank: its SD and mean, the actual acquirer's
    * mean rank with the t-statistic against one half, and how often the actual acquirer is the
    * closest candidate, against the chance rate
        sum nset_a, detail
        put N_`tag' `=string(r(N), "%12.0fc")'
        put medset_`tag' `=string(r(p50), "%4.0f")'
        put meanset_`tag' `=string(r(mean), "%5.1f")'
        sum real_match
        put base_`tag' `=string(r(mean), "%5.2f")'
        foreach m in a e {
            sum relrank_`m'
            put sd_`m'_`tag' `=string(r(sd), "%5.3f")'
            put mean_`m'_`tag' `=string(r(mean), "%5.3f")'
            sum relrank_`m' if real_match==100
            put meanactual_`m'_`tag' `=string(r(mean), "%5.3f")'
            ttest relrank_`m' == 0.5 if real_match==100
            put tactual_`m'_`tag' `=string(r(t), "%6.2f")'
            gen closest_`m' = (rk_`m'==1)
            sum closest_`m' if real_match==100
            put closestactual_`m'_`tag' `=string(100*r(mean), "%5.2f")'
            sum closest_`m'
            put closestall_`m'_`tag' `=string(100*r(mean), "%5.2f")'
            gen double pcl_`m' = 1/nset_`m'
            sum pcl_`m' if real_match==100
            put closestexp_`m'_`tag' `=string(100*r(mean), "%5.2f")'
        }

    * Share of firms with a zero misconduct rate on each side, and the distribution of the raw
    * difference in rates, for the motivation paragraph
        foreach m in a e {
            gen zeroA_`m' = (acquirer_misc_`m'==0)
            gen zeroT_`m' = (target_misc_`m'==0)
            gen zeroBoth_`m' = zeroA_`m' & zeroT_`m'
            sum zeroA_`m' if tag_a
            put zeroacq_`m'_`tag' `=string(100*r(mean), "%5.1f")'
            sum zeroT_`m' if tag_t
            put zerotar_`m'_`tag' `=string(100*r(mean), "%5.1f")'
            sum zeroBoth_`m'
            put zeroboth_`m'_`tag' `=string(100*r(mean), "%5.1f")'
            sum rawd_`m', detail
            put rawd_p50_`m'_`tag' `=string(r(p50), "%6.2f")'
            put rawd_p90_`m'_`tag' `=string(r(p90), "%6.2f")'
            put rawd_p99_`m'_`tag' `=string(r(p99), "%6.2f")'
            put rawd_max_`m'_`tag' `=string(r(max), "%6.2f")'
            put rawd_mean_`m'_`tag' `=string(r(mean), "%6.2f")'
            put rawd_skew_`m'_`tag' `=string(r(skewness), "%6.2f")'
        }

    * Size and the indicator: the share of firms with any disclosure by employee tercile, each side
        foreach side in a t {
            local emp = cond("`side'"=="a", "aemployees", "temployees")
            local cut = cond("`side'"=="a", "misc_cut_aa", "misc_cut_ta")
            xtile empter_`side' = `emp' if tag_`side', nq(3)
            forvalues q = 1/3 {
                sum `cut' if tag_`side' & empter_`side'==`q'
                put anydisc_`side'_ter`q'_`tag' `=string(100*r(mean), "%5.1f")'
            }
        }

    * Columns (1), (2), (5) and (6) of Table V or VI, re-estimated here for the numbers the text quotes
        foreach m in a e {
            local col = cond("`m'"=="a", 1, 5)
            foreach rhs in "relrank_`m'" "relrank_`m' `c1'" {
                reghdfe real_match `rhs', absorb(target_crd#acquired_year `industry') vce(cluster clustervar)
                put b`col'_`tag' `=string(abs(_b[relrank_`m']), "%6.3f")'
                put se`col'_`tag' `=string(_se[relrank_`m'], "%6.3f")'
                put p`col'_`tag' `=string(2*ttail(e(df_r), abs(_b[relrank_`m']/_se[relrank_`m'])), "%6.4f")'
                local col = `col' + 1
            }
        }

    * Serial acquirers: the candidate acquirer's number of deals in the year as a control, then
    * acquirer-by-year effects in its place
        bys acquirer_crd acquired_year: egen ndeals = total(real_match==100)
        reghdfe real_match relrank_a `c1' ndeals, absorb(target_crd#acquired_year `industry') vce(cluster clustervar)
        put bndeals_`tag' `=string(abs(_b[relrank_a]), "%6.3f")'
        put pndeals_`tag' `=string(2*ttail(e(df_r), abs(_b[relrank_a]/_se[relrank_a])), "%6.4f")'
        put bndealsctl_`tag' `=string(_b[ndeals], "%6.2f")'
        reghdfe real_match relrank_a `c1', absorb(target_crd#acquired_year acquirer_crd#acquired_year `industry') vce(cluster clustervar)
        put bacqfe_`tag' `=string(abs(_b[relrank_a]), "%6.3f")'
        put pacqfe_`tag' `=string(2*ttail(e(df_r), abs(_b[relrank_a]/_se[relrank_a])), "%6.4f")'

    * Rank x Same state inside the all-pairs sample: the within-state premium in the matching slope
        if "`tag'" == "full" {
            foreach m in a e {
                reghdfe real_match c.relrank_`m'##c.same_state retail_clients aum_ratio_z age_ratio_z employee_ratio_z, absorb(target_crd#acquired_year `industry') vce(cluster clustervar)
                put binteract_`m' `=string(abs(_b[c.relrank_`m'#c.same_state]), "%6.3f")'
                put pinteract_`m' `=string(2*ttail(e(df_r), abs(_b[c.relrank_`m'#c.same_state]/_se[c.relrank_`m'#c.same_state])), "%6.4f")'
                put bmain_`m' `=string(_b[relrank_`m'], "%6.2f")'
                put pmain_`m' `=string(2*ttail(e(df_r), abs(_b[relrank_`m']/_se[relrank_`m'])), "%6.4f")'
            }
        }

    * The nine alternative measures, column (2)/(6) controls, target-by-year and line-of-business
    * effects except in row 2, which absorbs acquisition-year effects only
        local j = 0
        foreach m in a e {
            local j = `j' + 1
            local col = `coloff' + `j'
            local rhs1 relrank_`m'
            local rhs2 relrank_`m'
            local rhs3 rawrank_`m'
            local rhs4 rdist_`m'
            local rhs5 pA_`m' pT_`m' int_p_`m'
            local rhs6 adist_`m'_z
            local rhs7 wdist_`m'_z
            local rhs8 bdist_`m'
            local rhs9 dA_`m' dT_`m' int_d_`m'
            local v5 int_p_`m'
            local v9 int_d_`m'
            forvalues r = 1/9 {
                local fe target_crd#acquired_year
                if `r' == 2 local fe acquired_year
                local v `rhs`r''
                if `r' == 5 local v `v5'
                if `r' == 9 local v `v9'
                reghdfe real_match `rhs`r'' `c1', absorb(`fe' `industry') vce(cluster clustervar)
                matrix ALT[`r', 3*`col'-2] = _b[`v']
                matrix ALT[`r', 3*`col'-1] = _se[`v']
                matrix ALT[`r', 3*`col']   = 2*ttail(e(df_r), abs(_b[`v']/_se[`v']))
                matrix NOBS[1, `col'] = e(N)
            }
        }
}


********************************************************************************
* The table, written by hand in the paper's fragment style: a coefficient row and a standard-error
* row per measure, stars from the p-values, observations last
********************************************************************************

* Row labels, as the paper prints them
    local lab1 "Misconduct Distance Rank"
    local lab2 "Misconduct Distance Rank, acquisition-year FE only"
    local lab3 "Misconduct Distance Rank, raw difference in rates"
    local lab4 "Percentile-rank distance, $|p_{A} - p_{T}|$"
    local lab5 "Percentile-rank interaction, \$p_{A} \times p_{T}\$"
    local lab6 "$|\text{asinh}(m_{A}) - \text{asinh}(m_{T})|$, standardized"
    local lab7 "$|m_{A} - m_{T}|$, winsorized, standardized"
    local lab8 "Bin distance (none, low, high)"
    local lab9 "Acq has disclosures $\times$ Tar has disclosures"

* Column headers
    file open ALT using "tables/matching_alt_measures.tex", write replace
    file write ALT "                &\multicolumn{1}{c}{(1)}         &\multicolumn{1}{c}{(2)}         &\multicolumn{1}{c}{(3)}         &\multicolumn{1}{c}{(4)}         \\" _n
    file write ALT "\toprule" _n
    file write ALT "& \multicolumn{2}{c}{\textbf{All candidate pairs}} &\multicolumn{2}{c}{\textbf{Within-state, one-year window}} \\[-0.4ex]" _n
    file write ALT "\cmidrule(r){2 - 3}" _n
    file write ALT "\cmidrule(r){4 - 5}" _n
    file write ALT "& \multicolumn{1}{c}{All} & \multicolumn{1}{c}{EMS} & \multicolumn{1}{c}{All} & \multicolumn{1}{c}{EMS} \\" _n
    file write ALT "\midrule" _n

* One coefficient row and one standard-error row per measure
    forvalues r = 1/9 {
        file write ALT "`lab`r''"
        forvalues c = 1/4 {
            local b = ALT[`r', 3*`c'-2]
            local p = ALT[`r', 3*`c']
            local star = cond(`p'<0.01, "\sym{***}", cond(`p'<0.05, "\sym{**}", cond(`p'<0.10, "\sym{*}", "")))
            file write ALT "&" %9.3f (`b') "`star'"
        }
        file write ALT "\\" _n
        file write ALT "                "
        forvalues c = 1/4 {
            local se = ALT[`r', 3*`c'-1]
            file write ALT "&  (" %5.3f (`se') ")"
        }
        file write ALT "\\" _n
        if `r' < 9 file write ALT "[0.25em]" _n
    }

* Observations and the closing rule
    file write ALT "\hline" _n
    file write ALT "Observations    "
    forvalues c = 1/4 {
        local n = NOBS[1, `c']
        file write ALT "&    " %9.0fc (`n') "   "
    }
    file write ALT "\\" _n
    file write ALT "\bottomrule" _n
    file close ALT
    file close NUM

* Echo the cells and the numbers into the log
    matrix list ALT
    matrix list NOBS
    type "tables/matching_rank_numbers.txt"
    type "tables/matching_alt_measures.tex"
