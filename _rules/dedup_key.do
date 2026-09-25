********************************************************************************
* Deterministic survivor keys and event units, so that ties resolve the same way
* on every run. Used by the merger-sample, matching, post-merger and separation
* producers. Usage: select "group variables" "priority variables" 1|_N.
********************************************************************************
args action key priority survivor

* select: sort by the priority variables, break remaining ties on every other
* variable in sorted order, and keep the survivor row in each group
if "`action'" == "select" {
    unab dk_all : _all
    unab dk_priority : `key' `priority'
    local dk_rest : list dk_all - dk_priority
    local dk_rest : list sort dk_rest
    bys `key' (`priority' `dk_rest'): keep if _n == `survivor'
    exit
}

* Unknown action
display as error "dedup_key: unknown dedup_key action `action'"
exit 198
