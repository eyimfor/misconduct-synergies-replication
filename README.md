# Replication package: Misconduct Synergies

Code that reproduces the 34 tables and figures in the paper, from the
BrokerCheck and IAPD adviser records, the SEC Form ADV filings and a hand-collected
merger list.

## Running it

1. **Raw data to foundational datasets.** With the compressed raw files in `../raw/`:

       bash CollectData/run_collect.sh

   This writes `SecIAPD/output/`, `2023/data/input/` and `upstream_inputs/`. It needs
   `zstd` on the PATH and about 15 GB of scratch space, and takes about 15 minutes.

2. **Foundational datasets to exhibits.**

       bash run_all.sh

   Tables are written to `2023/tables/` and figures to `2023/figures/`. The last step
   checks that every exhibit listed in `EXHIBITS.txt` was produced.

To use a different interpreter or Stata executable, set `PY` and `STATA`, for example
`PY=python3 STATA=stata-mp bash run_all.sh`.

## Requirements

- Stata 17 (MP). The user-written ado packages the code needs are in `environment/`,
  and every runner loads them from there.
- Python 3 with pandas, numpy, scipy, statsmodels, matplotlib, seaborn, pyreadstat and
  pyarrow. The results were produced with Python 3.13, pandas 2.2, numpy 2.1,
  statsmodels 0.14, matplotlib 3.10 and seaborn 0.13.

## Where to look

- `outline.txt`: the steps from raw data to exhibits, and which script makes each table
  and figure.
- `lineage.html`: the same map as a clickable picture.
- `data_dictionary.md`: the main datasets, with what writes and reads each one.
