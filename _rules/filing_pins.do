********************************************************************************
* Keeps the latest Form ADV filing per firm-fiscal-year (paper's data section),
* decided on numeric dates, then filing id where available, then the full row.
* Used by every exhibit that draws on firm_adv_controls or business lines, and
* by Table XII Panel B through the Form ADV-W withdrawals.
********************************************************************************
args action

* fiscal_month: keep the latest filing per firm-year
if "`action'" == "fiscal_month" {
    do "$PKG/_rules/dedup_key.do" select "crd year" "date_submitted filingid month_fiscal_year execution_date" _N
    exit
}

* industry_date: build the numeric submission date and year, and keep the
* business-line fields
if "`action'" == "industry_date" {
    gen date_submitted = date(execution_date, "MDY")
    gen year = year(date_submitted)
    keep crd year date_submitted filingid financial_planning port_mgmt_indv_sb port_mgmt_inv_c port_mgmt_pif port_mgmt_bus_insc pension_cs selection_advisers publication_periodicals ratings_pricing market_timing education_seminars other
    exit
}

* industry_last: keep the latest business-line filing per firm-year
if "`action'" == "industry_last" {
    do "$PKG/_rules/dedup_key.do" select "crd year" "date_submitted filingid" _N
    exit
}

* failure_last: keep the latest cease date per withdrawing firm
if "`action'" == "failure_last" {
    gen died = date(dateceased, "MDY")
    do "$PKG/_rules/dedup_key.do" select "crdnumber" "died dateceased fulllegalname reasonsforwithdrawal closure_reason" _N
    exit
}

* Unknown action
display as error "filing_pins: unknown filing_pins action `action'"
exit 198
