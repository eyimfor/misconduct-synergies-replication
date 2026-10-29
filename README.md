# Replication package: Misconduct Synergies

Code that reproduces the 37 tables and figures in the paper, from the
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

- `paper/Misconduct_Synergies.md`: the paper as Markdown: the full text, the notes of every
  exhibit, the variable glossary and the references. Each exhibit names the file the pipeline
  writes, the scripts that produce it and the section that discusses it.
- `exhibits.json`: the same exhibit-to-code map as data.
- `outline.txt`: the steps from raw data to exhibits, and which script makes each table
  and figure.
- The lineage page, https://claude.ai/artifact/BZEeuikwWihBzNhmLnh74G: the same map as a
  clickable picture.
- `data_dictionary.md`: the main datasets, with what writes and reads each one.

## Using the package with an LLM

`AGENTS.md` (the same text as `llms.txt`) is written for coding assistants such as Claude Code,
Codex or Cursor. It gives the paper's abstract, what to read first, how the pipeline runs, the
map from every exhibit to its code, and the mistakes that are easy to make here. Open the
package folder in the assistant and start with a prompt such as:

    Read AGENTS.md and paper/Misconduct_Synergies.md. Then tell me which scripts produce
    Table IX, what sample it uses, and where that sample is defined.

For a chat assistant without file access, attach `llms.txt` and the paper Markdown.

## License

The code is released under the MIT License (`LICENSE`). The hand-collected merger list,
`2023/data/input/new_mergers_raw.csv`, is released under CC BY 4.0; cite the paper when you
use it. The Stata packages in `environment/` keep their own licenses and authorship.
