# -*- coding: utf-8 -*-
"""Formats the summary-statistics fragments for Tables II, VII and VIII in the paper's layout.

The producer emits a bare `tabular` with six-decimal values, producer row labels,
producer row order, and (for stats_target_acquirer) a stray `crd` row. The paper
table has a spanning header, `scalebox`, paper row labels, paper row order and
two-decimal values.

The header layout lives in `templates/<name>.head` / `.foot`. The notes are not
code output and are not written here: they belong to the paper. The data rows are
regenerated from the producer, and the N in each header is counted from the dataset
the producer summarizes.
"""
import io, os, re, sys
import pandas as pd

# Paths, overridable from the environment
PKG = os.environ.get("PKG",  ".")                   # package root
SRC_DIR = os.environ.get("TABLES", PKG + "/2023/tables")                   # producer output
# Templates ship next to this script; TPL overrides the location
_here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "templates")
TPL = os.environ.get("TPL", _here)
OUT = os.environ.get("OUT",  "2023/tables") # where the fragments are written

# Producer label -> paper label, and producer rows to drop
LABELS = {
    "# Employees":                    r"\# Employees",
    "# Clients (000s)":               r"\# Clients (000s)",
    "AUM ($ Billions)":               r"AUM (\$ Billions)",
    "Employee disclosures (All)":     "Employee Disclosure (All)",
    "Employee misconduct (EMS)":      "Employee Misconduct (EMS)",
    "Employees misconduct (All)":     "Employee Disclosure (All)",
    "Employees misconduct (EMS)":     "Employee Misconduct (EMS)",
    "Any Employee disclosures (All)": "Any Employee Disclosure (All)",
    "Any Employee misconduct (EMS)":  "Any Employee Misconduct (EMS)",
}
DROP = {"crd"}

# Paper row order, by paper label
ORDER = {
 "stats_target_acquirer": [
    r"\# Employees","Employee Disclosure (All)","Employee Misconduct (EMS)",
    "Disclosure growth (All)","Misconduct growth (EMS)",
    "Any Employee Disclosure (All)","Any Employee Misconduct (EMS)",
    r"AUM (\$ Billions)","AUM growth",r"\# Clients (000s)","Client growth"],
 "stats_target_acquirerpp": [
    r"\# Employees","Employee Disclosure (All)","Employee Misconduct (EMS)",
    "Misconduct growth (All)","Misconduct growth (EMS)",
    r"AUM (\$ Billions)","AUM growth",r"\# Clients (000s)","Client growth"],
}
ORDER["stats_target_acquirerppf"] = ORDER["stats_target_acquirerpp"]

# N in each header column, counted from the dataset and group the producer summarizes
# (_8_summary_statistics.py, _8_tables7and8.py). Table II: firms per group, where
# target == 0 is the target column. Tables VII and VIII: pairs observed pre and post.
DATA = os.environ.get("DATA", PKG + "/2023/data/output")


def header_n(name):
    if name == "stats_target_acquirer":
        d = pd.read_stata(os.path.join(DATA, "target_acquirer_stats.dta"))
        return [int((d["target"] == 0).sum()), int((d["target"] == 1).sum())]
    f, treated = {"stats_target_acquirerpp":  ("misconductdroptest_table7.dta", 1),
                  "stats_target_acquirerppf": ("misconductdroptest_table8.dta", 0)}[name]
    d = pd.read_stata(os.path.join(DATA, f))
    d = d[d["treated"] == treated]
    return [int(d.loc[d["post"] == p, "id"].nunique()) for p in (0, 1)]


# Column widths for aligned LaTeX source
W = [31, 10, 11, 10, 11, 13, 16]


def two(x):
    """Six-decimal producer value -> two decimals; non-numeric passes through."""
    s = x.strip()
    m = re.fullmatch(r"(-?\d+(?:\.\d+)?)", s)
    return f"{float(m.group(1)):.2f}" if m else s


def parse(path):
    # Keep the seven-cell data rows of the producer's tabular; skip LaTeX commands
    rows = []
    for line in io.open(path, encoding="utf-8"):
        s = line.rstrip("\n")
        if "&" not in s or s.lstrip().startswith("\\"):
            continue
        cells = [c.strip() for c in s.rstrip().rstrip("\\").split("&")]
        if len(cells) != 7:
            continue
        rows.append(cells)
    return rows


def render(cells):
    # One paper row: paper label, four values at two decimals, then the last two cells as is
    lab = LABELS.get(cells[0], cells[0])
    vals = [two(c) for c in cells[1:5]] + [cells[5].strip(), cells[6].strip()]
    out = lab.ljust(W[0] - 1) + " "
    parts = [out]
    for i, v in enumerate(vals, start=1):
        parts.append("&" + v.rjust(W[i] - 1) + " ")
    return "".join(parts).rstrip() + " \\\\"


def port(name):
    # Map producer rows to paper labels, dropping the rows in DROP
    rows = parse(os.path.join(SRC_DIR, name + ".tex"))
    kept = {}
    for c in rows:
        if c[0] in DROP:
            continue
        kept[LABELS.get(c[0], c[0])] = c

    # Stop if a paper row is missing; rows not in the paper are dropped and reported
    order = ORDER[name]
    missing = [k for k in order if k not in kept]
    extra = [k for k in kept if k not in order]
    if missing:
        raise SystemExit(f"{name}: producer is missing paper rows {missing}")

    # Write header (with the N filled in), rows in paper order, and footer
    body = "\n".join(render(kept[k]) for k in order)
    head = io.open(os.path.join(TPL, name + ".head"), encoding="utf-8").read()
    n1, n2 = header_n(name)
    head = head.replace("@N1@", str(n1)).replace("@N2@", str(n2))
    foot = io.open(os.path.join(TPL, name + ".foot"), encoding="utf-8").read()
    io.open(os.path.join(OUT, name + ".tex"), "w", encoding="utf-8", newline="\n").write(head + body + foot)
    note = f"  (dropped {extra})" if extra else ""
    print(f"wrote {name}.tex  {len(order)} rows{note}")


if __name__ == "__main__":
    # Port Table II, then Tables VII and VIII
    for n in ["stats_target_acquirer", "stats_target_acquirerpp", "stats_target_acquirerppf"]:
        port(n)
