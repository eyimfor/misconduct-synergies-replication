********************************************************************************
* Merger year restriction: restricts the sample to mergers completed between
* 2011 and 2020 (acquired_year).
********************************************************************************

* Keep mergers completed 2011-2020
    keep if acquired_year >=2011 & acquired_year <=2020
