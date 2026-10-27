********************************************************************************
* Aligns employee counts to the fiscal year in which the paper measures them.
* Firm characteristics are measured in the fiscal year before the merger; AUM per
* registered employee is measured in year t+1.
* Exhibits: Tables V, VI, XII (Panels A and B), A.4 and A.5; Figures 2 and 3.
********************************************************************************
* Usage: employee_timing.do pair <target_crd|acquirer_crd> | calendar | aum_lead | failure_load.
args operation role

* pair: attach the firm-year panel to each fiscal year and rename the firm key to the role
    if "`operation'" == "pair" {
        keep crd_number fiscal_year
        isid crd_number fiscal_year
        gen year = fiscal_year
        merge 1:1 crd_number year using data/output/firm_year_panel
        drop if _m == 2
        drop _m

        * Missing disclosure measures are zero
        foreach x in egan_intensity_flow egan_intensity_three any_intensity_flow any_intensity_three any_disclosureall egan_disclosureall {
            replace `x' = 0 if `x' == .
        }
        xtset crd_number fiscal_year
        ren crd_number `role'
        exit
    }

* calendar: set year to the fiscal year
    if "`operation'" == "calendar" {
        gen year = fiscal_year
        exit
    }

* aum_lead: the t+1 lead takes both AUM and employees at t+1
    if "`operation'" == "aum_lead" {
        gen double ln_aum_emp_current = ln(dollar_aum/employees)
        gen double ln_aum_emp = f.ln_aum_emp_current
        do "$PKG/_rules/fiscal_window.do" aum
        exit
    }

* failure_load: load the regression sample and set the AUM year to the fiscal year
    if "`operation'" == "failure_load" {
        use data/output/all_regression, clear
        do "$PKG/_rules/fiscal_window.do" aum
        gen year_aum = fiscal_year
        * Closure at t+1 is known from the withdrawal date; no post-closure ADV filing is required.
        exit
    }

* Any other operation is an error
    display as error "Unknown employee_timing operation: `operation'"
    exit 198
