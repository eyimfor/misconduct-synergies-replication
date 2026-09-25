********************************************************************************
* Firm-year membership: which firm-years enter an exhibit and which are dropped
* for missing data. Used by Tables III, IV, XII, A.2, A.3, A.4, A.6 and A.9
* and Figure 1, among others, and through the matched pairs by the exhibits
* built on them.
********************************************************************************
* Usage: gate support | load support dataset.
* support = logged (drops zero AUM), general (requires employees and AUM),
*   matching (requires AUM only).
args action support payload

* Load the dataset if asked, and validate the arguments
    if "`action'" == "load" {
        use `payload', clear
    }
    else if "`action'" != "gate" exit 198
    if !inlist("`support'", "logged", "general", "matching") exit 198

* Require non-missing Form ADV and employment data; specifications that take
* ln(AUM) also require positive AUM
    if "`support'" != "matching" drop if employees == .
    drop if dollar_aum == .
    local positive = ("`support'" == "logged")
    if `positive' drop if dollar_aum == 0
