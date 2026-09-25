********************************************************************************
* The merger-year window, applied where the merger list is read. The sample
* covers mergers from January 2011 through December 2020. Used by every exhibit
* built on the merger sample.
********************************************************************************
* Usage: yearvar filter; yearvar project "vars"; yearvar rename "old vars" "new vars";
*        yearvar load "dataset" ["projection"] ["keep-if expression"].
args yearvar operation first second third

* Prepare the data for the requested operation
    if "`operation'" == "project" {
        keep `first'
    }
    else if "`operation'" == "rename" {
        rename `first' `second'
    }
    else if "`operation'" == "load" {
        use `first', clear
    }
    else if "`operation'" != "filter" {
        display as error "merger_window: unknown preparation operation `operation'"
        exit 198
    }

* Apply the year restriction for the given event-year variable
    if "`yearvar'" == "mergeryear" {
        do "$PKG/_helpers/restrict_merger_year.do"
    }
    else if "`yearvar'" == "acquired_year" {
        do "$PKG/_helpers/restrict_acquired_year.do"
    }
    else {
        display as error "merger_window: unsupported event-year variable `yearvar'"
        exit 198
    }

* For load, apply the optional projection and keep-if expression
    if "`operation'" == "load" {
        if `"`second'"' != "" {
            keep `second'
        }
        if `"`third'"' != "" {
            keep if `third'
        }
    }
