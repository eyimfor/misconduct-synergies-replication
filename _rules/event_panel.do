********************************************************************************
* Builds the event-time panel around each merger and attaches outcomes to it.
* The paper's event window is years -3 to +3 relative to the merger at t = 0.
* Used by Table IX (pseudo-merger panel), Table X and Figure 5 (separations),
* Table XI and Figure 6; exhibits built from those panels inherit it.
********************************************************************************
* Usage: year "broker/firm key" offset; pair "partner keys"; presence;
*        merge cardinality "pair/time keys" "using file"; join "event keys" "using file".
args action first second third

* year: set year to acquired_year plus the row's position within key and merger
* year, less the offset
    if "`action'" == "year" {
        bys `first' acquired_year: replace year = acquired_year + _n - `second'
        exit
    }

* pair: build event times -5 to +5 (11 rows per pair); callers then keep -3 to +3
    if "`action'" == "pair" {
        egen id = group(`first' acquired_year)
        expand 11, gen(event_time)
        bys id acquired_year: replace event_time = _n - 6
        exit
    }

* presence: keep a merger pair observed at least one year before the merger and in
* or after the merger year
    if "`action'" == "presence" {
        keep if min_event <= -1 & max_event >= 0
        exit
    }

* merge: attach outcomes; the merge keys must include acquired_year
    if "`action'" == "merge" {
        unab ep_key : `second'
        local ep_event acquired_year
        local ep_has_event : list ep_event in ep_key
        if !`ep_has_event' {
            display as error "event_panel: event attachment must include acquired_year"
            exit 198
        }
        merge `first' `second' using `third'
        exit
    }

* join: form all pairwise combinations on the event keys
    if "`action'" == "join" {
        joinby `first' using `second'
        exit
    }

* Any other action is an error
    display as error "event_panel: unknown event_panel action `action'"
    exit 198
