********************************************************************************
* Broker or adviser filter, included by other do-files: keeps advisers who hold
* a broker or investment adviser qualification.
********************************************************************************

* Keep brokers and investment advisers, identified from their exam qualifications
    drop if cum_exams ==0
    gen advisers = (series65_m == 1| (series66_m == 1 & generalsecrep_m==1))
    gen brokers = ((securityessentialsexam == 1)|(generalsecrep == 1))
    gen brokeroradviser = (brokers ==1 | advisers ==1)
    keep if brokeroradviser
