********************************************************************************
* Processes exams to sum qualifications in each year; writes exam_summary.dta
********************************************************************************
clear

* Import the dataset of exams and record the year each exam was taken
    import delimited "../SecIAPD/output/exams_all2024.csv", varnames(1) clear
    gen examyear = year(date(examtakendate, "MDY"))
    save data/output/exam_summary, replace

* Expand to one observation per year, from the first exam year through 2022
    use data/output/exam_summary, clear
    keep b_crd examyear
    bys b_crd (examyear): keep if _n == 1
    expand 2023 - examyear
    bys b_crd (examyear): gen year = examyear + _n - 1

* Merge the exams back and flag the years with a new exam
    drop if year ==.
    drop examyear
    ren year examyear
    merge 1:m b_crd examyear using data/output/exam_summary
    drop if _m ==2
    gen took_new_exam = (_m ==3)
    drop _m

* Calculate the cumulative number of exams taken by each broker by year, and
* flag exams of scope BC
    ren examyear year
    bys b_crd (year): gen cum_exams = sum(took_new_exam)
    gen broker = (examscope == "BC")
    keep b_crd year cum_exams broker

* Collapse to one observation per broker-year, flag brokers with any BC exam,
* and save
    bys b_crd year (cum_exams broker): keep if _n == _N
    bys b_crd: egen only_broker = max(broker)
    drop broker
    ren b_crd b_crd_number
    destring b_crd_number, replace force
    save data/output/exam_summary, replace
