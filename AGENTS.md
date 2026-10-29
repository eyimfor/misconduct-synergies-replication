# Misconduct Synergies: replication package

> Code that reproduces the 37 code-produced tables and figures in Tookes and Yimfor,
> "Misconduct Synergies", from the BrokerCheck and IAPD adviser records, the SEC Form ADV
> filings and a hand-collected list of investment-adviser mergers.

You are working with the replication package for "Misconduct Synergies" by Heather Tookes and
Emmanuel Yimfor. Read this file before the code. It says where the paper, the data map and the
exhibit map are, how the pipeline runs, and which mistakes are easy to make here.

**The paper.** Do corporate control transactions discipline the labor force? We find that new disclosures of employee misconduct in the investment advisory industry drop by between 19 and 23 percent following mergers. Consistent with synergies due to business model or asset complementarities, targets and acquirers have better pre-merger misconduct records compared to peers and, within the subsample of merging firms, there is assortative matching on misconduct. Mergers facilitate further reductions in misconduct through separations of target firm employees with high misconduct. Many separated employees remain in the industry, suggesting that mergers play a role in the redistribution of misconduct across firms.

## Read first

- `paper/Misconduct_Synergies.md`: the full text (Sections I-VI), the notes of every exhibit,
  the variable glossary (Table A.1) and the references. Each exhibit entry names the file the
  pipeline writes, the scripts that produce it and the section that discusses it. Variable
  definitions are in the glossary; use them before reading code.
- `exhibits.json`: the same exhibit map as data. For each exhibit: number, title and LaTeX
  label; for each of its files: the path, the producing scripts, the `run_all.sh` steps that run
  them, and the input datasets (as the node ids of the lineage page).
- `data_dictionary.md`: the main datasets, with rows, columns, and what writes and reads each.
- `outline.txt`: every step from raw data to exhibits, in prose.
- The lineage page, https://eyimfor.github.io/misconduct-synergies-replication/: the same map as a
  clickable picture.

## How it runs

1. `bash CollectData/run_collect.sh` takes the compressed raw archives in `../raw/` (one folder
   above the package; not in this repository) to the foundational files in `SecIAPD/output/`,
   `2023/data/input/` and `upstream_inputs/`. About 15 minutes; needs `zstd` on the PATH and
   about 15 GB of scratch space.
2. `PKG=/path/to/package bash run_all.sh` takes the foundational files to every exhibit: tables
   in `2023/tables/`, figures in `2023/figures/`. About 40 minutes. The Stata runners
   `_runners/01`-`17` build the panels, the sample and the estimates; the Python producers draw
   the figures and summary tables; `CreateTables/_9_port_tables.py` and
   `_9_port_stats_tables.py` turn the raw estimate tables in `2023/tables_producer/` into the
   fragments the paper inputs; the last step checks that every file in `EXHIBITS.txt` was
   written. `PY` and `STATA` choose the interpreters.

## Layout

```
CollectData/    raw/ -> foundational files          CreateTables/   one producer per table
BuildPanels/    -> adviser-year, firm-year panels   CreateFigures/  one producer per figure
CreateSample/   merger list -> 485-deal sample      _runners/       numbered Stata steps
_rules/         shared sample definitions           _helpers/       shared restriction files
environment/    pinned Stata ado packages           2023/           all built data and exhibits
```

## Exhibits

Paper number, the file the pipeline writes, and the scripts that produce it, in order.

```
Figure 1               2023/figures/DisclosuresAll.png
                       <- CreateFigures/figure_disclosures.do, CreateFigures/_0_figure1_disclosures.py
Figure 2 (Panel A)     2023/figures/assortative_matching.png
                       <- CreateFigures/_0_figure2_all_pairs.py
Figure 2 (Panel B)     2023/figures/assortative_matching_emploc_robust.png
                       <- CreateFigures/_0_figure2_within_state.py
Figure 3 (Panel A)     2023/figures/matching_rank_panelA_all.png
                       <- CreateFigures/_0_figure3_matching_rank.py
Figure 3 (Panel B)     2023/figures/matching_rank_panelB_state.png
                       <- CreateFigures/_0_figure3_matching_rank.py
Figure 4               2023/figures/plottable11.png
                       <- CreateFigures/_1_figure4_combined_disclosures.py
Figure 5 (Panel A)     2023/figures/Figure5_Target_DiD.png
                       <- CreateTables/separations_target.do
Figure 5 (Panel B)     2023/figures/Figure5_Acquirer_DiD.png
                       <- CreateTables/separations_acquirer.do
Figure 6               2023/figures/Figure6_PureSeparation_DiD.png
                       <- CreateFigures/counterfactual_no_separation.do, CreateFigures/misconduct_drop_counterfactual.do
Table I                2023/tables/count_mergers.tex
                       <- CreateTables/_8_summary_statistics.py, CreateTables/_9_port_tables.py
Table II               2023/tables/stats_target_acquirer.tex
                       <- CreateSample/stats_target_firm.do, CreateSample/stats_acquirer_firm.do, CreateSample/stats_target_acquirer_firm.do, CreateTables/_8_summary_statistics.py, CreateTables/_9_port_stats_tables.py
Table III              2023/tables/target_regression_fraction_bad_three_z.tex
                       <- CreateTables/target_regression_build.do, CreateTables/target_regression_table.do, CreateTables/_9_port_tables.py
Table IV               2023/tables/acquirer_regression_fraction_bad_three_z.tex
                       <- CreateTables/acquirer_regression_build.do, CreateTables/acquirer_regression_table.do, CreateTables/_9_port_tables.py
Table V                2023/tables/matching_regression.tex
                       <- CreateTables/matching_baseline.do, CreateTables/_9_port_tables.py
Table VI               2023/tables/matching_regression_TimeWindow2023.tex
                       <- CreateTables/matching_time_window.do, CreateTables/_9_port_tables.py
Table VII              2023/tables/stats_target_acquirerpp.tex
                       <- CreateTables/_8_tables7and8.py, CreateTables/_9_port_stats_tables.py
Table VIII             2023/tables/stats_target_acquirerppf.tex
                       <- CreateTables/_8_tables7and8.py, CreateTables/_9_port_stats_tables.py
Table IX               2023/tables/post_misc_regs.tex
                       <- CreateTables/post_merger_misconduct_real.do, CreateTables/post_merger_misconduct_pseudo.do, CreateTables/pseudo_real_merger_test.do, CreateTables/_9_port_tables.py
Table X                2023/tables/fired_post.tex
                       <- CreateTables/separations_target.do, CreateTables/separations_acquirer.do, CreateTables/_9_port_tables.py
Table XI               2023/tables/matching_counterfactual.tex
                       <- CreateTables/misconduct_drop_employee.do, CreateTables/_9_port_tables.py
Table XII (Panel A)    2023/tables/misc_reverts_regression_a.tex
                       <- CreateTables/aum_per_employee.do, CreateTables/_9_port_tables.py
Table XII (Panel B)    2023/tables/aum_misc_change.tex
                       <- CreateTables/build_adv_withdrawal_failures.do, CreateTables/firm_closure.do, CreateTables/_9_port_tables.py
Figure A1              2023/figures/misconduct_trends_employee.png
                       <- CreateFigures/fines_per_year.do, CreateFigures/_1_fines_per_year.py
Figure A2 (Panel A)    2023/figures/figA2_panelA_transfer.png
                       <- CreateFigures/_2_figA2_extract_employment.py, CreateFigures/_2_figA2_compute_metrics.py, CreateFigures/_2_figA2_panels.py
Figure A2 (Panel B)    2023/figures/figA2_panelB_headcount.png
                       <- CreateFigures/_2_figA2_extract_employment.py, CreateFigures/_2_figA2_compute_metrics.py, CreateFigures/_2_figA2_panels.py
Figure A2 (Panel C)    2023/figures/figA2_panelC_deregistration.png
                       <- CreateFigures/_2_figA2_extract_employment.py, CreateFigures/_2_figA2_compute_metrics.py, CreateFigures/_2_figA2_panels.py
Figure A3 (Panel A)    2023/figures/figA3_panelA_dynamic.png
                       <- CreateFigures/figA3_estimation/run_figA3.py, CreateFigures/_3_figA3_plot.py
Figure A3 (Panel B)    2023/figures/figA3_panelB_alternatives.png
                       <- CreateFigures/figA3_estimation/run_figA3.py, CreateFigures/_3_figA3_plot.py
Table A.2              2023/tables/target_regressionind.tex
                       <- CreateTables/appendix_industry_controls.do, CreateTables/_9_port_tables.py
Table A.3              2023/tables/acquirer_regressionind.tex
                       <- CreateTables/appendix_industry_controls.do, CreateTables/_9_port_tables.py
Table A.4              2023/tables/matching_regressionindustry.tex
                       <- CreateTables/appendix_industry_controls.do, CreateTables/_9_port_tables.py
Table A.5              2023/tables/matching_alt_measures.tex
                       <- CreateTables/matching_alt_measures.do, CreateTables/_9_port_tables.py
Table A.6              2023/tables/frequent_acquirers_crd.tex
                       <- CreateTables/_8_frequent_acquirers.py
Table A.7              2023/tables/post_misc_regsfreq.tex
                       <- CreateTables/appendix_industry_controls.do, CreateTables/_9_port_tables.py
Table A.8              2023/tables/post_misc_regs_examqual.tex
                       <- CreateTables/BrokerRegistrationRobustness/run_all.do, CreateTables/BrokerRegistrationRobustness/05_appendix_exam_table.do, CreateTables/_9_port_tables.py
Table A.9              2023/tables/separationmerger.tex
                       <- CreateTables/labor_outcomes_table.do, CreateTables/_9_port_tables.py
Table A.10             2023/tables/mathing.tex
                       <- CreateTables/ma_employee_misconduct.do, CreateTables/_9_port_tables.py
```

## Things that are easy to get wrong

- Stata exits 0 even when a do-file fails. Judge a step by its log: `run_all.sh` greps each log
  for `r(nnn);` and non-zero `RC_` macros. A step that reports ok is still not an exhibit; the
  final exhibit-accounting step is what confirms each file was written.
- Paths are case-sensitive (`2023/data`, not `2023/Data`). The default macOS filesystem hides
  such mistakes; a case-sensitive volume catches them.
- Stata `.dta` files embed a save timestamp, so identical data gives different bytes. Compare
  contents (Stata `cf`, pandas), not file hashes.
- Sample definitions (event windows, filters, winsorizing, clustering) live once in `_rules/`
  and every producer calls them. Change a definition there, not inside a producer.
- Table captions and notes are in the paper, not the package; the package writes table bodies.
- `b_crd_number` identifies an individual adviser; `crd_number`, `organizationcrd` and `crd`
  identify a firm. Both are FINRA CRD numbers.
- The estimation sample is 485 mergers completed 2011-2020, the earliest deal per target, with
  Form ADV data for both firms in the year before the merger. The merger list is
  `2023/data/input/new_mergers_raw.csv`.
- A fresh clone holds code only: built data, exhibits and logs are git-ignored and appear after
  the two stages above.

## Requirements

Stata 17 MP (ado packages in `environment/`). Python 3 with pandas, numpy, scipy, statsmodels,
matplotlib, seaborn, pyreadstat and pyarrow; the results were produced with Python 3.13, pandas
2.2, numpy 2.1, statsmodels 0.14, matplotlib 3.10 and seaborn 0.13.

## Citation

Tookes, Heather, and Emmanuel Yimfor. "Misconduct Synergies." Working paper.
