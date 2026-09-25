********************************************************************************
* Imports and cleans adviser disclosures and builds adviser_disclosures,
* rr_disclosuresyear and the adviser-year panel rr_disclosures_panel.
********************************************************************************
clear


********************************************************************************
* Adviser disclosures (union of the 2020, 2022 and 2024 scrapes)
********************************************************************************

* Import the disclosures and rename the fields
    import delimited ../SecIAPD/output/disclosures_2024.csv, clear varnames(1)
    ren damagesamount damagesgranted
    keep individualid eventdate disclosuretype disclosureresolution damagesgranted
    ren (individualid eventdate disclosuretype disclosureresolution damagesgranted) ///
        (b_crd_number event_date disclosure_type disclosure_resolution settlement_amount)

* Keep only valid CRD numbers and dated disclosure events
    drop if b_crd_number == .
    gen date_event = date(event_date, "MDY")
    format date_event %td
    drop if date_event == .
    drop event_date

* Disclosure classes as in Egan, Matvos and Seru (2019): customer disputes
    gen cd_settled = (disclosure_type == "Customer Dispute" & disclosure_resolution == "Settled")
    gen cd_denied = (disclosure_type == "Customer Dispute" & disclosure_resolution == "Denied")
    gen cd_c_na = (disclosure_type == "Customer Dispute" & disclosure_resolution == "Closed-No Action")
    gen cd_final = (disclosure_type == "Customer Dispute" & disclosure_resolution == "Final")
    gen cd_pending = (disclosure_type == "Customer Dispute" & disclosure_resolution == "Pending")
    gen cd_dismissed = (disclosure_type == "Customer Dispute" & disclosure_resolution == "Dismissed")
    gen cd_award_judgement = (disclosure_type == "Customer Dispute" & ///
                              disclosure_resolution == "Award / Judgment")
    gen cd_wdrawn = (disclosure_type == "Customer Dispute" & disclosure_resolution == "Withdrawn")

* Employment separation after allegations
    gen sep_after_alleg = (disclosure_type == "Employment Separation After Allegations")

* Regulatory
    gen reg_final = (disclosure_type == "Regulatory" & disclosure_resolution == "Final")
    gen reg_pending = (disclosure_type == "Regulatory" & disclosure_resolution == "Pending")
    gen reg_appeal = (disclosure_type == "Regulatory" & disclosure_resolution == "On Appeal")

* Criminal
    gen crim_final = (disclosure_type == "Criminal" & disclosure_resolution == "Final Disposition")
    gen crim_pending = (disclosure_type == "Criminal" & disclosure_resolution == "Pending Charge")
    gen crim_appeal = (disclosure_type == "Criminal" & disclosure_resolution == "On Appeal")

* Financial
    gen financial_final = (disclosure_type == "Financial" & disclosure_resolution == "Final")
    gen fin_pending = (disclosure_type == "Financial" & disclosure_resolution == "Pending")

* Civil
    gen civil_pending = (disclosure_type == "Civil" & disclosure_resolution == "Pending")
    gen civil_appeal = (disclosure_type == "Civil" & disclosure_resolution == "On Appeal")
    gen civil_final = (disclosure_type == "Civil" & disclosure_resolution == "Final")

* Judgment/lien, investigation and civil bond
    gen jd_lean = (disclosure_type == "Judgment / Lien")
    gen investigation = (disclosure_type == "Investigation")
    gen civil_bond  = (disclosure_type == "Civil Bond")

* Drop duplicates and convert the settlement amount to a number
    duplicates drop
    replace settlement_amount = subinstr(settlement_amount, "$", "", .)
    replace settlement_amount = subinstr(settlement_amount, ",", "", .)
    destring settlement_amount, replace

* Sum disclosures under the full (any) and the Egan et al. (egan) classifications
    egen egan_intensity = rowtotal(cd_settled reg_final sep_after_alleg ///
                                   cd_award_judgement crim_final civil_final)
    egen any_intensity = rowtotal(cd_settled sep_after_alleg reg_final crim_final ///
                                  cd_award_judgement civil_final financial_final ///
                                  cd_denied jd_lean cd_c_na fin_pending cd_pending cd_wdrawn crim_pending ///
                                  investigation reg_pending civil_pending cd_final ///
                                  cd_dismissed civil_bond reg_appeal crim_appeal civil_appeal)
    gen year_disclosure = year(date_event)
    save data/output/adviser_disclosures, replace


********************************************************************************
* Yearly disclosures for each adviser
********************************************************************************

* Sum each disclosure class and the settlement amount by adviser and year
    use data/output/adviser_disclosures, clear
    replace settlement_amount = 0 if settlement_amount ==-99
    foreach x in cd_settled sep_after_alleg reg_final crim_final ///
                 cd_award_judgement civil_final financial_final cd_denied jd_lean ///
                 cd_c_na fin_pending cd_pending cd_wdrawn ///
                 crim_pending investigation reg_pending civil_pending ///
                 cd_final cd_dismissed civil_bond reg_appeal crim_appeal civil_appeal settlement_amount{
        bys b_crd_number year: egen `x'd = sum(`x')
    }

* Keep one row per adviser and disclosure year
    drop cd_settled sep_after_alleg reg_final crim_final ///
         cd_award_judgement civil_final financial_final cd_denied jd_lean ///
         cd_c_na fin_pending cd_pending cd_wdrawn ///
         crim_pending investigation reg_pending civil_pending ///
         cd_final cd_dismissed civil_bond reg_appeal crim_appeal civil_appeal ///
         disclosure_type disclosure_resolution settlement_amount date_event
    drop egan_intensity any_intensity
    duplicates drop

* Count all disclosures for each adviser in each disclosure year
    egen egan_intensity = rowtotal(cd_settled reg_final sep_after_alleg ///
                                   cd_award_judgement crim_final civil_final)
    egen any_intensity = rowtotal(cd_settled sep_after_alleg reg_final crim_final ///
                                  cd_award_judgement civil_final financial_final ///
                                  cd_denied jd_lean cd_c_na fin_pending cd_pending cd_wdrawn crim_pending ///
                                  investigation reg_pending civil_pending cd_final ///
                                  cd_dismissed civil_bond reg_appeal crim_appeal civil_appeal)
    save data/output/rr_disclosuresyear, replace


********************************************************************************
* Adviser-year panel of disclosures, with missing years filled with zero
********************************************************************************

* Fill in every year from 1996 for each adviser with a disclosure
    use data/output/rr_disclosuresyear, clear
    gen year = year_disclosure
    keep b_crd_number year
    duplicates drop
    xtset b_crd_number year
    keep if year >= 1996
    tsfill, full

* Merge the yearly disclosures onto the full panel
    gen year_disclosure = year
    merge 1:1 b_crd_number year_disclosure using data/output/rr_disclosuresyear
    drop if _m ==2 // disclosure events before 1996
    drop _m

* Replace missing disclosures with zero
    foreach x in cd_settled sep_after_alleg reg_final crim_final ///
                 cd_award_judgement civil_final financial_final cd_denied jd_lean ///
                 cd_c_na fin_pending cd_pending cd_wdrawn ///
                 crim_pending investigation reg_pending civil_pending ///
                 cd_final cd_dismissed civil_bond reg_appeal crim_appeal civil_appeal ///
                 settlement_amountd egan_intensity any_intensity ///
                 {
        replace `x' = 0  if `x' == .
    }

* Sum egan_intensity, any_intensity and settlement amounts over the current and previous two years
    foreach x in egan_intensity any_intensity  settlement_amount{
        rangestat (sum) `x', interval(year -2 0) by(b_crd_number)
    }

* Cumulative disclosures; save the panel of advisers with at least one disclosure
    bys b_crd_number (year): gen cumulative_disclosures = sum(any_intensity)
    bys b_crd_number (year): gen cumulative_disclosures_egan = sum(egan_intensity)
    keep b_crd_number year egan_intensity any_intensity egan_intensity_sum ///
         any_intensity_sum settlement_amountd settlement_amountd_sum cumulative_disclosures cumulative_disclosures_egan
    save data/output/rr_disclosures_panel, replace
