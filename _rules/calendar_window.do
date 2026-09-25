********************************************************************************
* Calendar coverage of the adviser and Form ADV panels. Exhibits: Figure A.1
* (settlements); Table X and Figure 5, Panel A (target_did); Tables VII-IX and
* A.6, Figures 4 and A.3 (adviser_event); every exhibit built on the filing data
* (adv_fiscal). Usage: settlements | target_did | adviser_event | adv_fiscal.
********************************************************************************
args action

* Aggregate settlements are tabulated by calendar year from 2001 to 2021
    if "`action'" == "settlements" {
        keep if year >= 2001 & year <= 2021
        exit
    }

* Target difference-in-differences panel from 2009, with misconduct indicators
    if "`action'" == "target_did" {
        use data/output/regressionbrokerstarget2, clear
        keep if year >= 2009
        gen has_misconduct_any = (any_intensity_sum > 0)
        gen has_misconduct_egan = (egan_intensity_sum > 0)
        exit
    }

* The adviser-year panel of employment and disclosures: apply the event-time
* restrictions, then keep years 2009 through 2022
    if "`action'" == "adviser_event" {
        do "$PKG/_helpers/restrict_event_time.do"
        keep if year >= 2009
        do "$PKG/_helpers/restrict_last_year.do"
        exit
    }

* The Form ADV panel covers fiscal years 2009 to 2022
    if "`action'" == "adv_fiscal" {
        gen adviser_age = year - firstyear + 1
        keep if fiscal_year >= 2009 & fiscal_year <= 2022
        ren crd organizationcrd
        exit
    }

* Any other action is an error
    exit 198
