********************************************************************************
* What counts as a separation, and when an adviser leaves the sample. Post-merger
* moves between the merging firms do not count as separations, and each adviser
* exits the sample after a first separation. Exhibits: Table X, Panel B and
* Figure 5, Panel B; the target side uses the same definition.
********************************************************************************
* Usage: partner "partner-employment flag"; censor "broker/firm keys".
args action key

* Moves to the merger partner after the merger are not separations
    if "`action'" == "partner" {
        replace separation = 0 if separation == 1 & `key' & (year - acquired_year >= 0)
        exit
    }

* First separation year and last observed year for each adviser-firm-merger
    if "`action'" == "censor" {
        bys `key' acquired_year: egen min_sep = min(year) if separation
        bys `key' acquired_year: egen min_separation = min(min_sep)
        bys `key' acquired_year: egen max_year = max(year)
        exit
    }

* Any other action is an error
    display as error "separation: unknown separation action `action'"
    exit 198
