********************************************************************************
* Fiscal year restriction: sample filter included by other do-files. Keeps
* fiscal years 2010-2021.
********************************************************************************

* Keep fiscal years 2010-2021
    keep if fiscal_year<=2021 & fiscal_year >=2010
