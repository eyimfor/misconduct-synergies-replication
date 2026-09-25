********************************************************************************
* Produces Figure 6, figures/Figure6_PureSeparation_DiD.png: combined-firm
* misconduct of the pre-merger cohort, actual (advisers still at the merged firm)
* vs. counterfactual (all pre-merger advisers still in the industry). The gap is
* the pure effect of separations. Deletes its intermediate .dta files at the end.
********************************************************************************
clear


********************************************************************************
* Part 1: counterfactual series
********************************************************************************
* Counterfactual series: the disclosure rate of the pre-merger cohort wherever its
* advisers work. The merge is on b_crd_number and year only, so an adviser who
* separated is counted at the new firm.

* Load the adviser-year pairs in the employment data
    use data/output/adviser_firm_year, clear
    keep b_crd_number year
    duplicates drop

* Attach the pre-merger cohort on adviser and year only, so misconduct at a new firm counts
    merge 1:m b_crd_number year using data/output/fig6_adviser_panel
    keep if _m ==3  // Keep only brokers in both datasets (still in industry)
    drop _m
    * _m==3 keeps cohort advisers still registered somewhere in the industry;
    * advisers who left the industry (_m==2) drop out of the counterfactual

* Aggregate misconduct to firm-year level: count the tracked cohort
    * For each merger-year: cohort advisers still in the industry, the number with a
    * disclosure, and the percentage
    bys id year: egen employees = nvals(b_crd_number)

* Count employees with each type of misconduct
    bys id year: egen all_intensity_flow1 = nvals(b_crd_number) if any_intensity >0
    bys id year: egen egan_intensity_flow1 = nvals(b_crd_number) if egan_intensity >0
    bys id year: egen all_intensity_flow = nvals(b_crd_number) if any_intensity_sum >0
    bys id year: egen egan_intensity_flow = nvals(b_crd_number) if egan_intensity_sum >0
    bys id year: egen all_intensity_flowN = nvals(b_crd_number) if cumulative_disclosures >0
    bys id year: egen egan_intensity_flowN = nvals(b_crd_number) if cumulative_disclosures_egan >0

* Convert counts to percentages of employees
    foreach x in all_intensity_flow1 egan_intensity_flow1 all_intensity_flow ///
                 egan_intensity_flow all_intensity_flowN egan_intensity_flowN{
        bys id year: egen `x'm = max(`x')
        replace `x'm = 0 if `x'm ==.
        replace `x'm = ((`x'm)/employees)*100  // Convert to percentage
        drop `x'
    }

* Keep firm-year level data only
    keep id year event_time all_intensity_flow1m egan_intensity_flow1m ///
         all_intensity_flowm egan_intensity_flowm all_intensity_flowNm egan_intensity_flowNm employees acquired_year
    duplicates drop
    ren (all_intensity_flowm egan_intensity_flowm) (any_misconduct egan_misconduct)

* Mark this as the counterfactual series and save it
    gen counterfactual = 1
    save data/output/postmergercombinedfirmcounterfactual_puresep, replace


********************************************************************************
* Part 2: actual series
********************************************************************************
* Actual series: the disclosure rate among cohort advisers still at the target or
* acquirer. The merge is on b_crd_number, crd and year, so only advisers at the
* merged firm count.

* Keep only advisers currently employed at the target or acquirer (merge on adviser, firm and year)
    do "$PKG/_rules/merge_semantics.do" combined_membership

* Aggregate misconduct to firm-year level: count employees currently at the merged firm
    bys id year: egen employees = nvals(b_crd_number)

* Count employees with misconduct (same logic as the counterfactual)
    bys id year: egen all_intensity_flow1 = nvals(b_crd_number) if any_intensity >0
    bys id year: egen egan_intensity_flow1 = nvals(b_crd_number) if egan_intensity >0
    bys id year: egen all_intensity_flow = nvals(b_crd_number) if any_intensity_sum >0
    bys id year: egen egan_intensity_flow = nvals(b_crd_number) if egan_intensity_sum >0
    bys id year: egen all_intensity_flowN = nvals(b_crd_number) if cumulative_disclosures >0
    bys id year: egen egan_intensity_flowN = nvals(b_crd_number) if cumulative_disclosures_egan >0

* Convert counts to percentages of employees
    foreach x in all_intensity_flow1 egan_intensity_flow1 all_intensity_flow ///
                 egan_intensity_flow all_intensity_flowN egan_intensity_flowN{
        bys id year: egen `x'm = max(`x')
        replace `x'm = 0 if `x'm ==.
        replace `x'm = ((`x'm)/employees)*100
        drop `x'
    }

* Keep firm-year level data only
    keep id year event_time all_intensity_flow1m egan_intensity_flow1m ///
         all_intensity_flowm egan_intensity_flowm all_intensity_flowNm egan_intensity_flowNm employees acquired_year
    duplicates drop
    ren (all_intensity_flowm egan_intensity_flowm) (any_misconduct egan_misconduct)

* Mark this as the actual series and save it
    gen counterfactual = 0
    save data/output/postmergercombinedfirmreal_puresep, replace


********************************************************************************
* Part 3: combine both series
********************************************************************************

* Stack the counterfactual and actual series
    use data/output/postmergercombinedfirmcounterfactual_puresep, clear
    append using data/output/postmergercombinedfirmreal_puresep
    duplicates drop
    // Winsorization is applied once to the final regression sample (see winsorize_last.do)
    save data/output/postmergercombinedfirmcounterfactual_puresep, replace


********************************************************************************
* Part 4: difference-in-differences event study
********************************************************************************
* Stacked regression of the disclosure rate on the Actual indicator and its
* interactions with event-year dummies (t = -1 omitted), with merger, year and
* merger-by-year fixed effects. Negative post-merger coefficients mean the actual
* rate is below the counterfactual.

* Keep the event window t = -3 to 3
    use data/output/postmergercombinedfirmcounterfactual_puresep, clear
    keep if event_time >= -3 & event_time <= 3

* Create treated indicator (1 = actual firm, 0 = counterfactual firm)
    gen treated = (counterfactual == 0)
    * Two rows per merger-year: Actual (counterfactual = 0, treated = 1) and
    * Counterfactual (counterfactual = 1, treated = 0)

* Interact each pre-merger event year with treated status
    forvalues i=3(-1)1{
        gen pre_`i' = (event_time==-`i' & treated==1)
    }

* Interact the merger year (t=0) and each post-merger year with treated status
    gen current = (event_time==0 & treated==1)
    forvalues i=1(1)3{
        gen post_`i' = (event_time==`i' & treated==1)
    }

* Omit t=-1 as base period (standard DiD normalization)
    replace pre_1 = 0
    * Coefficients are relative to t = -1, the year before the merger

* Winsorize the outcome and run the DiD regression
    do "$PKG/_rules/winsorize_last.do" figure6_final "any_misconduct"
    reghdfe any_misconduct pre_3 pre_2 pre_1 current ///
            post_1 post_2 post_3 treated ///
            , absorb(id##year) vce(cluster id)
    * id##year absorbs merger, year and merger-by-year effects, so the coefficients
    * compare the two series within each merger-year; standard errors are clustered by merger

* Plot the event-time coefficients
    coefplot, keep(pre_* current post_*) levels(95) vertical lcolor(black) mcolor(black) ///
        coeflabels(pre_3 = "-3" pre_2 = "-2" pre_1 = "-1" current = "0" post_1= "1" post_2= "2" post_3= "3") ///
        omitted msymbol(line) recast(connect) ///
        ytitle("Actual - Counterfactual (% Employees with Misconduct)", size(small)) ///
        ylabel(, labsize(small) angle(horizontal) nogrid format(%3.1f)) ///
        yline(0, lwidth(vthin) lpattern(solid) lcolor(black)) ///
        xtitle("Years Relative to Merger", size(medium)) ///
        xlabel(,labsize(small)) graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) ///
        ciopts(recast(rcap) lpattern(dash) lcolor(navy)) ///
        xline(4, lwidth(vthin) lpattern(dash) lcolor(black))
    * Plot the Actual minus Counterfactual difference by event year with 95% confidence intervals

* Export at a fixed 7.5 x 4.5 in (720 x 432 px) canvas: Stata's default graph size differs by version
    graph display, xsize(7.5) ysize(4.5)
    graph export "figures/Figure6_PureSeparation_DiD.png", as(png) width(720) replace

* Report the output file
    di "Difference-in-Differences event study complete for PURE SEPARATION EFFECT"
    di "Output files:"
    di "  - Figure: figures/Figure6_PureSeparation_DiD.png"


********************************************************************************
* Cleanup: delete intermediate files not needed for follow-on analysis
********************************************************************************

* Delete the two intermediate series files
    erase data/output/postmergercombinedfirmcounterfactual_puresep.dta
    erase data/output/postmergercombinedfirmreal_puresep.dta
    di ""
    di "Pure separation analysis complete!"
