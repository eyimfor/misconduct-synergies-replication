# Data dictionary

This file describes the datasets the pipeline builds and then analyses. They are Stata
`.dta` files and they live in `2023/data/output/`, except for the two adviser-level event
panels, which are written to `2023/data/output_robust/`, and the merger entry list, which is
written to `2023/data/input/` alongside the raw merger list it is derived from.

The build writes about 120 datasets in all. Most of them are working files that one script
saves and the next script immediately reads back. The thirty-four datasets below are
either a stage's finished product or an input that several downstream scripts share. They
are listed in the order the pipeline creates them: the adviser panels first, then the firm-level controls and misconduct measures, then the
merger sample, then the matching frames that pair each real merger with a counterfactual,
and finally the event panels the regressions run on.

Row and column counts are for the files as the pipeline produces them.

Two conventions apply to the "Read by" columns. First, `b_crd_number`
identifies an individual adviser or broker and `crd_number` (or `organizationcrd`, or `crd`)
identifies a firm; both are CRD numbers issued by FINRA. Second, the numbered runner scripts
in `_runners/` re-open each file after the stage that writes it and print its row count as a
check. Those reads are not listed below, because every runner would otherwise appear against
every dataset in its stage.

---

## Adviser panels

These are built from the BrokerCheck and IAPD record scrapes. They are the largest files in
the package: `adviser_firm_year.dta` is about 3 GB, and `exam_qualifications.dta` about
1.4 GB.

| File | Rows × Columns | One row is | Written by | Read by |
|---|---|---|---|---|
| `adviser_registration_spells.dta` | 5,375,675 × 9 | One continuous spell during which one individual was registered with one firm, with the spell's start and end dates and the office city, state and ZIP. | `build_employment_panel.do` | Only `build_employment_panel.do`, which reads it back twice to derive `adviser_year` and `adviser_firm_year`. |
| `adviser_year.dta` | 21,001,910 × 2 | One individual in one calendar year, covering every year from that person's first registration to their last. | `build_employment_panel.do` | `build_employment_panel.do`, which range-joins it back onto the spells to produce `adviser_firm_year`, and `03_build_status_robustness.do`. |
| `adviser_firm_year.dta` | 34,257,343 × 8 | One individual at one firm in one calendar year: the employment panel that says who worked where and when. | `build_employment_panel.do` | `firm_misconduct_levels.do`, `separations_target.do`, `separations_acquirer.do`, `post_merger_misconduct_real.do`, `post_merger_misconduct_pseudo.do`, `counterfactual_no_separation.do`, `misconduct_drop_employee.do`, `misconduct_drop_counterfactual.do`, `ma_employee_misconduct.do`, `_2_figA2_extract_employment.py`, and the shared routines `merge_semantics.do` and `labor_outcomes.do`. |
| `exam_qualifications.dta` | 25,729,846 × 14 | One individual in one year, with an indicator for each qualifying exam (Series 7, 63, 65, 66, 6, 24, and so on) the person had passed by then, plus a count of other qualifications. | `build_exam_panel.do` | `separations_target.do`, `separations_acquirer.do`, `misconduct_drop_employee.do`, `03_build_status_robustness.do`, and the shared routine `merge_semantics.do`. |
| `exam_summary.dta` | 25,729,846 × 4 | One individual in one year, with the cumulative number of exams passed and a flag for people whose exams are all on the broker-dealer side. | `process_exams.do` | `separations_target.do`, `separations_acquirer.do`. |
| `adviser_disclosures.dta` | 445,759 × 31 | One disclosure event on one individual's record (a customer complaint, regulatory action, criminal charge, civil suit or financial event), with its type, how it was resolved, the settlement amount and the date. | `build_disclosure_panel.do` | `build_disclosure_panel.do`, which reads it back to build the yearly and person-year disclosure panels that the rest of the pipeline uses, and the Figure A.3 scripts in `figA3_estimation/`. |

## Firm controls and firm-level misconduct

The controls come from the SEC's Form ADV bulk filings; the misconduct measures are the
adviser-level disclosures aggregated to the employing firm.

| File | Rows × Columns | One row is | Written by | Read by |
|---|---|---|---|---|
| `firm_adv_controls.dta` | 188,990 × 57 | One Form ADV filing: the filing firm's name, address, business lines, compensation arrangements, assets under management, client and employee counts, and the fiscal year the filing reports on. | `build_firm_controls_data.do` | `build_matching_pairs.do`, `matching_baseline.do`, `matching_time_window.do`, `pseudo_real_merger_test.do`, `stats_target_firm.do`, `stats_acquirer_firm.do`, `target_regression_build.do`, `acquirer_regression_build.do`, `appendix_industry_controls.do`, `aum_per_employee.do`, `_8_frequent_acquirers.py`, and the shared routines `target_crd_known.do` and `merge_semantics.do`. |
| `adv_filing_dates.dta` | 278,025 × 10 | One firm-year, pinned to the filing that defines that year's reporting window, with the fiscal year, fiscal month and the date range the filing's data covers. | `build_fiscal_year_filings.do` | `build_firm_controls_data.do`. |
| `firm_year_panel.dta` | 1,507,996 × 13 | One firm in one year from 1996 to 2023, with the firm's headcount and its misconduct measures: new disclosures that year, disclosures over the trailing three years, the number of employees with a disclosure, and fines. | `firm_misconduct_levels.do` | `build_matching_pairs.do`, `stats_target_firm.do`, `stats_acquirer_firm.do`, `target_regression_build.do`, `acquirer_regression_build.do`, `aum_per_employee.do`, `figure_disclosures.do`, `fines_per_year.do`, and the shared routine `employee_timing.do`. |
| `firm_year_panel_ltd.dta` | 540,594 × 19 | One firm-year, restricted to firm-years with a known headcount, with misconduct expressed per employee and its one-, two- and three-year lags: the variables the counterfactual match is built on. | `build_matching_pairs.do` | Only `build_matching_pairs.do`, which merges it into the matching criteria and then joins it back for the pre-trend check. |
| `firm_misconduct.dta` | 626,834 × 10 | One firm-year with the misconduct aggregates only, before headcount and the full 1996-2023 calendar are merged in. | `firm_misconduct_levels.do` | Only `firm_misconduct_levels.do`, which merges it onto the firm-year skeleton to finish `firm_year_panel.dta`. |

## The merger sample

The merger list enters the pipeline once, through a shared routine that applies the sample
window (deals completed 2011-2020) and keeps the earliest deal per target. The summary-statistics
scripts then narrow it to the deals where both sides have usable Form ADV data.

| File | Rows × Columns | One row is | Written by | Read by |
|---|---|---|---|---|
| `new_mergers_entry.dta` (in `data/input/`) | 626 × 9 | One adviser merger, with the deal identifier, target and acquirer CRD numbers, merger year, announcement and closing dates, deal type and the two firm names. This is the validated entry point for the merger list. | `merger_list.do`, under its `prepare` action | `merger_list.do`, under its `load` action, which every script that needs the merger list calls rather than opening the file itself. |
| `merger_sample.dta` | 485 × 9 | One completed merger inside the 2011-2020 sample window with summary statistics on both the target and the acquirer side. | `merger_summary_stats.do` | `build_matching_pairs.do`, `matching_baseline.do`, `matching_time_window.do`, `figure_disclosures.do`, `_8_summary_statistics.py`, `_8_frequent_acquirers.py`, `_2_figA2_extract_employment.py`, `_2_figA2_compute_metrics.py`, the Figure A.3 scripts in `figA3_estimation/`, and the shared routine `event_list.do`. |
| `target_stats.dta` | 514 × 19 | One acquired firm, measured in the year before it is acquired: headcount, misconduct shares, assets under management, client count, firm age, and AUM and client growth. | `stats_target_firm.do` | `merger_summary_stats.do`, `stats_target_acquirer_firm.do`. |
| `acquirer_stats.dta` | 578 × 22 | One acquiring firm, measured in the year before the deal, with the same characteristics as the target file plus the retail-client indicator. | `stats_acquirer_firm.do` | `merger_summary_stats.do`, `stats_target_acquirer_firm.do`. |
| `both.dta` | 485 × 3 | One target-acquirer-year deal for which both sides appear in the statistics files: the deal-level key the merger sample is cut down to. | `merger_summary_stats.do` and `stats_target_acquirer_firm.do` each write it, from the same block of code | `merger_summary_stats.do`, `stats_target_acquirer_firm.do`. |

## The matching frames

Two distinct things happen here, and they use different files. `build_matching_pairs.do`
finds a counterfactual (pseudo) target and acquirer for each real deal, matching on industry,
year, a binary misconduct split, three lagged misconduct splits and an employee decile.
`matching_baseline.do` and `matching_time_window.do` build a different object: for each
target, the set of all acquirers active in the same year, which is what the assortative-matching
regressions treat as the choice set. Each of the two also saves its estimation sample with the
Misconduct Distance Rank, the regressor of Tables V and VI, for the appendix table of
alternative measures.

| File | Rows × Columns | One row is | Written by | Read by |
|---|---|---|---|---|
| `matching_criteria.dta` | 98,403 × 26 | One firm-year that is eligible to take part in the match, carrying the industry, business lines, misconduct deciles and employee decile the match keys on. | `build_matching_pairs.do` | Only `build_matching_pairs.do`. |
| `matching_criteria_two.dta` | 90,457 × 26 | The same firm-year rows, restricted to firms that are never a target or an acquirer: the pool from which pseudo targets and pseudo acquirers are drawn. | `build_matching_pairs.do` | Only `build_matching_pairs.do`. |
| `real_target.dta` | 464 × 26 | One real acquired firm in the year before its deal, with the matching variables attached. | `build_matching_pairs.do` | `build_matching_pairs.do`, `pseudo_real_merger_test.do`, `02_rebuild_baseline_outcomes.do`, `03_build_status_robustness.do`. |
| `real_acquirer.dta` | 354 × 26 | One real acquiring firm in the year before its deal, with the same matching variables. | `build_matching_pairs.do` | `build_matching_pairs.do`, `pseudo_real_merger_test.do`, `02_rebuild_baseline_outcomes.do`, `03_build_status_robustness.do`. |
| `counterfactual_target.dta` | 461 × 4 | One real target paired with the pseudo target chosen for it, plus how many real targets that pseudo firm serves. | `build_matching_pairs.do` | Only `build_matching_pairs.do`. |
| `counterfactual_acquirer.dta` | 351 × 4 | One real acquirer paired with the pseudo acquirer chosen for it, plus how many real acquirers that pseudo firm serves. | `build_matching_pairs.do` | Only `build_matching_pairs.do`. |
| `pseudo_merger_pairs.dta` | 437 × 6 | One pseudo merger: the real target and real acquirer on one side, the pseudo target and pseudo acquirer standing in for them on the other, and the deal year. | `build_matching_pairs.do` | `build_matching_pairs.do`, `pseudo_real_merger_test.do`. |
| `merger_pairs_long.dta` | 1,748 × 4 | One firm in one role within one matched set (real target, pseudo target, pseudo acquirer or real acquirer, numbered 0 to 3), so each matched set contributes four rows. This is the long-form key the event panels are built from. | `build_matching_pairs.do` | `post_merger_misconduct_real.do`, `post_merger_misconduct_pseudo.do`, `pseudo_real_merger_test.do`, `counterfactual_no_separation.do`, `misconduct_drop_employee.do`, `02_rebuild_baseline_outcomes.do`, `03_build_status_robustness.do`, the Figure A.3 scripts in `figA3_estimation/`, and the shared routine `merge_semantics.do`. |
| `merger_pairs_unique.dta` | 1,196 × 2 | One distinct firm-year appearing anywhere in the matched sets, real or pseudo. | `build_matching_pairs.do` | `misconduct_drop_employee.do`. |
| `matching_frame.dta` | 19,829 × 38 | One candidate target-acquirer pairing in one deal year (every acquirer active that year crossed with every target), flagged for whether it is the pairing that actually happened, with both sides' misconduct and headcount and the combined misconduct measures. | `matching_baseline.do` | `matching_baseline.do`, `_0_figure2_all_pairs.py`, `_0_figure3_matching_rank.py`. |
| `matching_frame_full.dta` | 19,829 × 94 | The same candidate pairings, with each side's Form ADV characteristics attached: state, disciplinary history, business lines, compensation arrangements, AUM, clients and firm age, suffixed `_a` for the acquirer and `_t` for the target. | `matching_baseline.do` | `matching_baseline.do`, `appendix_industry_controls.do`. |
| `matching_frame_tw.dta` | 15,408 × 45 | One candidate pairing under the within-state, one-year window: every acquirer with employees in one of the target's states and a deal within a year, with both sides' misconduct and headcount but before the Form ADV characteristics are attached. | `matching_time_window.do` | `matching_time_window.do`, `_0_figure2_within_state.py`, `_0_figure3_matching_rank.py`. |
| `matching_frame_timewin.dta` | 15,408 × 99 | The same object built under the tighter time window, and additionally carrying the two firms' employee counts by state and how many states they share. | `matching_time_window.do` | Only `matching_time_window.do`. |
| `matching_sample_full.dta` | 19,321 × 137 | The Table V estimation sample: the candidate pairings of `matching_frame_full.dta` that survive the sample rule in `_rules/winsorize_last.do`, with the pair controls standardized over that sample and, for each candidate acquirer, its Misconduct Distance Rank (All and EMS) within the target's candidate set. | `matching_baseline.do` | `matching_alt_measures.do`. |
| `matching_sample_timewin.dta` | 14,833 × 141 | The Table VI estimation sample, built the same way from `matching_frame_timewin.dta`. | `matching_time_window.do` | `matching_alt_measures.do`. |

## Event panels

These are what the post-merger regressions run on. `adviser_event_panel.dta` is at the level
of the merged pair; the two files in `data/output_robust/` are at the level of the individual
adviser and are the largest outputs of the merger analysis.

| File | Rows × Columns | One row is | Written by | Read by |
|---|---|---|---|---|
| `adviser_event_panel.dta` | 5,506 × 34 | One matched set in one event year, from three years before the deal to three years after, with the combined firm's headcount, misconduct flows, AUM, clients and age, a treated indicator separating real from pseudo mergers, and the post-merger indicator the difference-in-differences uses. | `pseudo_real_merger_test.do`, through the shared routine `winsorize_last.do` | `pseudo_real_merger_test.do`, `appendix_industry_controls.do`, `01_replicate_baseline.do`, `02_rebuild_baseline_outcomes.do`, `_2_figA2_compute_metrics.py`, `_2_figA2_extract_employment.py`, and the Figure A.3 scripts in `figA3_estimation/`. |
| `event_panel_real.dta` (in `data/output_robust/`) | 6,863,854 × 16 | One individual adviser at one of the two real merging firms in one year, with that year's disclosures and fines, the running totals, and indicators for whether the person left the firm and whether they left the industry. | `post_merger_misconduct_real.do` | `post_merger_misconduct_real.do`, `02_rebuild_baseline_outcomes.do`, `03_build_status_robustness.do`, `04_estimate_status_robustness.do`, and the Figure A.3 scripts in `figA3_estimation/`. |
| `event_panel_pseudo.dta` (in `data/output_robust/`) | 6,296,342 × 16 | The same, for the advisers at the matched pseudo target and pseudo acquirer, which never actually merge. | `post_merger_misconduct_pseudo.do` | `post_merger_misconduct_pseudo.do`, `02_rebuild_baseline_outcomes.do`, `03_build_status_robustness.do`, `04_estimate_status_robustness.do`, and the Figure A.3 scripts in `figA3_estimation/`. |
