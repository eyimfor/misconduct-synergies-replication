********************************************************************************
* Builds exam_qualifications.dta: one row per adviser and year with indicators
* for each qualification exam passed by that year (Series 6, 7, 24, 63, 65, 66
* and others).
********************************************************************************
clear


********************************************************************************
* Exam indicators by adviser and exam year
********************************************************************************

* Import the exam records and date each exam by year
    import delimited "../SecIAPD/output/exams_all2024.csv", varnames(1) clear
    gen examyear = year(date(examtakendate, "MDY"))
    drop if examyear ==.

* Flag each exam type
    gen investmentadviserexam = (examcategory == "Series 65"|examcategory == "Series 66")
    gen series65 = (examcategory == "Series 65")
    gen series66 = (examcategory == "Series 66")
    gen series79 = (examcategory == "Series 79")
    gen series82 = (examcategory == "Series 82")
    gen series2 = (examcategory == "Series 2")
    gen securityessentialsexam = (examcategory == "SIE")
    gen securitiesagentstatelaw = (examcategory == "Series 63")
    gen generalsecrep= (examcategory == "Series 7")
    gen investmentcompanyprep = (examcategory == "Series 6")
    gen gensecprincipal = (examcategory == "Series 24")

* Flag the main exams and count the distinct other exams per adviser and year
    gen mainexams = (investmentadviserexam == 1|securitiesagentstatelaw == 1|generalsecrep == 1| ///
                     investmentcompanyprep ==1|gensecprincipal ==1)
    bys b_crd examyear: egen otherquals = nvals(examcategory) if mainexams == 0
    bys b_crd examyear: egen otherqualifications = max(otherquals)
    replace otherqualifications = 0 if otherqualifications ==.

* Take the maximum of each indicator within adviser and year
    keep b_crd examyear investmentadviserexam series65 series66 series2 series79 series82 ///
         securityessentialsexam securitiesagentstatelaw ///
         generalsecrep investmentcompanyprep gensecprincipal mainexams otherqualifications
    foreach x in investmentadviserexam series65 series66 series2 series79 series82 ///
                 securityessentialsexam securitiesagentstatelaw generalsecrep investmentcompanyprep gensecprincipal mainexams otherqualifications ///
                 {
        bys b_crd examyear: egen `x'_m = max(`x')
    }

* Keep one row per adviser and year, with a running count of other qualifications
    keep b_crd examyear investmentadviserexam_m series65_m series66_m series2_m series79_m series82_m ///
         securityessentialsexam_m ///
         securitiesagentstatelaw_m generalsecrep_m investmentcompanyprep_m gensecprincipal_m mainexams_m otherqualifications_m
    bys b_crd examyear: keep if _n == _N
    bys b_crd (examyear): gen otherquals = sum(otherqualifications_m)
    save data/output/exam_qualifications, replace


********************************************************************************
* Qualifications held in every year through 2022
********************************************************************************

* Create one observation for each year from the first exam through 2022
    use data/output/exam_qualifications, clear
    keep b_crd examyear
    bys b_crd (examyear): keep if _n == 1
    expand 2023 - examyear
    bys b_crd (examyear): gen year = examyear + _n - 1

* Attach each year's exam records, then carry qualifications forward
    drop if year ==.
    drop examyear
    ren year examyear
    merge 1:m b_crd examyear using data/output/exam_qualifications
    drop if _m ==2
    drop _m
    ren examyear year
    foreach x in investmentadviserexam series65 series66 series2 series79 series82  securityessentialsexam ///
                 securitiesagentstatelaw generalsecrep_m investmentcompanyprep gensecprincipal otherquals{
        bys b_crd (year): carryforward `x', replace
    }

* Once an exam is taken, the broker holds that qualification in every later year
    foreach x in investmentadviserexam series65 series66 series2 series79 series82 securityessentialsexam ///
                 securitiesagentstatelaw generalsecrep_m investmentcompanyprep gensecprincipal{
        bys b_crd (year): replace `x' = 1 if `x'[_n-1] == 1
    }

* Keep the qualification indicators and save
    keep b_crd year investmentadviserexam_m series65_m series66_m series2_m series79_m series82_m ///
         securityessentialsexam_m ///
         securitiesagentstatelaw_m generalsecrep_m investmentcompanyprep_m gensecprincipal_m otherquals
    destring b_crd, replace
    ren b_crd b_crd_number
    save data/output/exam_qualifications, replace
