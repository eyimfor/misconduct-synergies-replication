********************************************************************************
* aum: fiscal years 2010 to 2021, for the value-relevance regressions (Table XII, Panels A and B).
* Tables III and IV apply their 2010-2019 window through _helpers/restrict_fiscal_2010_2019.do.
* Usage: fiscal_window.do aum.
********************************************************************************
args family

* Restrict to fiscal years 2010 to 2021
    if "`family'" == "aum" {
        do "$PKG/_helpers/restrict_fiscal_2010_2021.do"
        exit
    }

* Reject an unknown family
    display as error "Unknown fiscal_window family: `family'"
    exit 198
