********************************************************************************
* Test fixture for the labor-outcome attach rule in "$PKG/_rules/labor_outcomes.do".
* Runs the rule on hand-built advisers with known expected destinations and asserts
* the results. All data are tempfiles; no pipeline input or output is changed.
********************************************************************************
clear

* Build the employment history of the fixture advisers
    tempfile fixture_history fixture_roster fixture_original
    input long b_crd_number long crd_number int labor_first_emp_year int labor_last_emp_year
1 10 2010 2015
2 200 2016 2016
3 300 2020 2020
4 40 2010 2020
5 500 2016 2016
6 600 2016 2016
7 70 2010 2016
7 700 2016 2016
8 800 2016 2016
8 801 2017 2017
9 900 2015 2015
10 1000 2010 2014
10 100 2010 2016
12 1200 2010 2016
    end
    isid b_crd_number crd_number
    save `fixture_history'

* Build the merger roster of origin and partner firms
    clear
    input byte labor_role long labor_origin_crd int acquired_year long crd_number byte labor_in_unit
1 10 2015 10 1
1 20 2015 20 1
1 30 2015 30 1
1 40 2015 40 1
1 50 2015 50 1
1 50 2015 500 1
1 60 2016 60 1
1 60 2016 600 1
1 70 2015 70 1
2 80 2015 80 1
2 80 2015 800 1
2 80 2015 801 1
1 90 2015 90 1
1 100 2015 100 1
1 110 2015 110 1
1 120 2014 120 1
1 120 2018 120 1
    end
    isid labor_role labor_origin_crd acquired_year crd_number
    save `fixture_roster'

* Build the test cases with their expected outcomes
    clear
    input long labor_source_row long b_crd_number byte labor_role long labor_origin_crd int acquired_year int year byte post_merger int separation byte expected_left byte expected_other byte expected_return byte expected_future int expected_last str32 case_name
1 1 1 10 2015 2015 1 100 1 0 0 0 2015 "no_future_registration"
2 2 1 20 2015 2015 1 100 0 1 0 1 2016 "next_year_outside"
3 3 1 30 2015 2015 1 100 0 1 0 1 2020 "late_outside"
4 4 1 40 2015 2015 1 100 0 0 1 1 2020 "future_origin_only"
5 5 1 50 2015 2015 1 100 0 0 1 1 2016 "post_partner_only"
6 6 1 60 2016 2015 0 100 0 1 0 1 2016 "pre_merger_partner_transfer"
7 7 1 70 2015 2015 1 100 0 1 0 1 2016 "concurrent_origin_and_outside"
8 8 2 80 2015 2015 1 100 0 0 1 1 2017 "multiple_acquirer_partners"
9 9 1 90 2015 2015 1 100 1 0 0 0 2015 "same_year_only_outside"
10 10 1 100 2015 2015 1 100 0 0 1 1 2016 "past_outside_future_origin"
11 11 1 110 2015 2015 1 0 . . . . . "nonleaver_missing_destination"
12 12 1 120 2014 2014 1 100 0 1 0 1 2016 "same_adviser_earlier_event"
13 12 1 120 2018 2018 1 100 1 0 0 0 2016 "same_adviser_later_event"
    end
    unab fixture_original_vars : _all
    save `fixture_original'

* Run the attach rule on the test cases
    scalar LABOR_history_last_year = 2022
    do "$PKG/_rules/labor_outcomes.do" attach "`fixture_history'" "`fixture_roster'"

* Check that the rows and original variables are unchanged
    assert _N == 13
    isid labor_source_row
    sort labor_source_row
    cf `fixture_original_vars' using `fixture_original', all

* Check the outcomes against the expected values
    assert labor_left_industry == expected_left
    assert labor_join_different == expected_other
    assert labor_return_only == expected_return
    assert labor_future_any == expected_future
    assert labor_future_other == expected_other
    assert labor_last_emp_year == expected_last

* Check the observed endpoint and follow-up years
    assert labor_observed_endpoint == 2022
    assert labor_followup_years == 7 if labor_source_row <= 11
    assert labor_followup_years == 8 if labor_source_row == 12
    assert labor_followup_years == 4 if labor_source_row == 13
    list case_name labor_left_industry labor_join_different labor_return_only, noobs abbreviate(32)

* Run the attach rule on a panel with no leavers (only the nonleaver case)
    use `fixture_original', clear
    keep if separation == 0
    tempfile fixture_zero_leavers
    save `fixture_zero_leavers'
    do "$PKG/_rules/labor_outcomes.do" attach "`fixture_history'" "`fixture_roster'"

* Check that a complete role panel with no leavers keeps its row with missing destinations
    assert _N == 1
    cf `fixture_original_vars' using `fixture_zero_leavers', all
    assert missing(labor_left_industry) & missing(labor_join_different) & missing(labor_return_only)
    assert missing(labor_future_any) & missing(labor_future_other) & missing(labor_last_emp_year)
    display "LABOR_FIXTURE_CASES=14"
    display "LABOR_FIXTURE_FINISHED=1"
