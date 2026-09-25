# -*- coding: utf-8 -*-
"""Converts the producers' LaTeX output into the table fragments the paper inputs:
Tables I, III-VI, IX-XII, A.2-A.4 and A.6-A.9. Relabels variables, swaps rules and
adds the panel headers and fixed-effect rows the paper prints."""
import io, os, re

# Paths, overridable from the environment
PKG = os.environ.get("PKG",  ".")                   # package root
SRC_DIR = os.environ.get("TABLES", PKG + "/2023/tables")                   # producer output
OUT = os.environ.get("OUT",  "2023/tables") # where the fragments are written

# Producer label -> paper label (longest / most specific first)
LABELS = [
    ("Employees with misconduct (Egan)", "Employee Misconduct (EMS)"),
    ("Employees with misconduct (All)",  "Employee Disclosure (All)"),
    ("Employees with misconduct (EMS)",  "Employee Misconduct (EMS)"),
    ("Employees misconduct (All)",       "Employee Disclosure (All)"),
    ("Employees misconduct (EMS)",       "Employee Misconduct (EMS)"),
    ("Employee misconduct (All)",        "Employee Disclosure (All)"),
    ("Employee misconduct (EMS)",        "Employee Misconduct (EMS)"),
]


def commafy(line):
    """Add thousands separators to the numeric cells of an Observations row."""
    if not line.lstrip().startswith("Observations"):
        return line
    head, sep, rest = line.partition("&")
    return head + sep + re.sub(r"(?<![\d,.])\d{4,}(?![\d,.])",
                               lambda m: "{:,}".format(int(m.group(0))), rest)


# Apply LABELS, then any table-specific replacements, then commafy each line
def harmonize(text, extra=()):
    for a, b in LABELS:
        text = text.replace(a, b)
    for a, b in extra:
        text = text.replace(a, b)
    return "\n".join(commafy(l) for l in text.splitlines())


def body(name, extra=(), rule=r"\toprule"):
    """Producer fragment with its opening rule swapped for the paper's."""
    raw = io.open(os.path.join(SRC_DIR, name), encoding="utf-8").read()
    lines = harmonize(raw, extra).rstrip().splitlines()
    assert lines[1].strip() == r"\hline", (name, lines[1])
    lines[1] = rule
    return "\n".join(lines)


# Write a fragment to OUT and fail if it contains a control character
def write(rel, text):
    p = os.path.join(OUT, rel)
    io.open(p, "w", encoding="utf-8", newline="\n").write(text.rstrip() + "\n")
    bad = [c for c in "\t\x08\x07\r\x0c\x0b" if c in text]
    assert not bad, (rel, "control chars leaked", [hex(ord(c)) for c in bad])
    print("wrote", rel)


# Adds \addlinespace above the \hline before Observations; used for
# misc_reverts_regression_a.tex (Table XII, Panel A) and mathing.tex
HLINE_OBS = '\\hline\nObservations'
ADDL_HLINE_OBS = '\\addlinespace\n\\hline\nObservations'

# Column-group headers spanning columns 2-3 and 4-5
SPAN_DISC = (
    r"& \multicolumn{2}{c}{\textbf{Employee Disclosure (All)}}" "\n"
    r"&\multicolumn{2}{c}{\textbf{Employee Misconduct (EMS)}} \\[-0.4ex]" "\n"
    r"\cmidrule(r){2 - 3}" "\n"
    r"\cmidrule(r){4 - 5}" "\n"
)
SPAN_FLOW = (
    r"& \multicolumn{2}{c}{\textbf{Flow Disclosure (All)}}" "\n"
    r"&\multicolumn{2}{c}{\textbf{Flow Misconduct (EMS)}} \\[-0.4ex]" "\n"
    r"\cmidrule(r){2 - 3}" "\n"
    r"\cmidrule(r){4 - 5}" "\n"
)

# Closing \bottomrule appended to the fragments
BOT = "\n" + r"\bottomrule"


# ---- Main tables ----

# Table III / IV  (main-text prediction models)
write("target_regression_fraction_bad_three_z.tex",   body("target_regression.tex") + BOT)
write("acquirer_regression_fraction_bad_three_z.tex", body("acquirer_regression.tex") + BOT)

# Table V / VI  (matching)
write("matching_regression.tex", body("matching_regression_raw.tex") + BOT)
write("matching_regression_TimeWindow2023.tex",
      body("matching_regression_TimeWindow2023.tex", rule=r"\midrule") + BOT)

# Table IX  (post-merger misconduct)
write("post_misc_regs.tex",
      SPAN_DISC + body("post_misc_regs.tex", rule=r"\hline") + BOT)

# Table X  (separations): two producer files -> one two-panel fragment
tgt = body("fired_post_target.tex", rule=r"\hline")
acq = body("fired_post_acquirer.tex", rule=r"\hline")
acq_rows = "\n".join(acq.splitlines()[2:])          # drop col-number row + rule
write("fired_post.tex",
      r"\textbf{Panel A} &\multicolumn{4}{c}{\textbf{Target Employees}} \\" "\n"
      r"\midrule" "\n"
      + tgt + "\n"
      r"\bottomrule" "\n"
      r"Target Firm $\times$ Year FE  &X &X &X &X \\" "\n"
      r"\midrule" "\n"
      r"\textbf{Panel B} &\multicolumn{4}{c}{\textbf{Acquirer Employees}} \\" "\n"
      r"\midrule" "\n"
      + acq_rows + "\n"
      r"\bottomrule")
# The acquirer-side FE row is added by the paper's table wrapper, immediately after
# this fragment. Emitting it here too would print it twice.

# Table XI: target advisers' new disclosures
write("matching_counterfactual.tex",
      SPAN_FLOW
      + body("drop_disclosures.tex", rule=r"\hline",
             extra=((r"Merged $\times$ Post", r"Target $\times$ Post"),
                    ("Merged          &",     "Target          &")))
      + BOT + "\n"
      r"Cohort $\times$ Year FE  &X &X &X &X \\")

# Table XII: value relevance, Panel A (AUM per employee) and Panel B (firm closure)
write("misc_reverts_regression_a.tex",
      body("aumemp_withinfirm.tex").replace(HLINE_OBS,
                                            ADDL_HLINE_OBS) + BOT)
write("aum_misc_change.tex", body("failed.tex") + BOT)


# ---- Appendix tables and Table I ----

# Tables A.2, A.3, A.4, A.6 and A.9
write("target_regressionind.tex",        body("target_regressionind.tex") + BOT)
write("acquirer_regressionind.tex",      body("acquirer_regressionind.tex") + BOT)
write("matching_regressionindustry.tex", body("matching_regressionind.tex") + BOT)
write("post_misc_regsfreq.tex",
      SPAN_DISC + body("post_misc_regsfa.tex", rule=r"\hline") + BOT)
write("mathing.tex",
      body("mathing.tex").replace(HLINE_OBS,
                                  ADDL_HLINE_OBS) + BOT)

# Table A.7: the producer already writes the paper's labels, so copy it as is
write("post_misc_regs_examqual.tex",
      io.open(os.path.join(SRC_DIR, "post_misc_regs_examqual.tex"), encoding="utf-8").read())

# Table I: escape "#" for LaTeX and use the paper's column spec.
_src = os.path.join(SRC_DIR, "merger_table.tex")
_t = io.open(_src, encoding="utf-8").read()
_t = _t.replace(r"\begin{tabular}{lrrr}", r"{\begin{tabular}{lccc}")
_t = re.sub(r"(?<!\\)#", r"\\#", _t)
# the paper rules off above the Total row as well as below it
_t = re.sub(r"(?m)^(Total\s*&)", r"\\bottomrule\n\1", _t)
# close the brace opened before \begin{tabular}. Testing endswith("}") does not
# work here: \end{tabular} ends with a brace of its own.
_t = _t.rstrip()
if _t.endswith(r"\end{tabular}"):
    _t += "}"
write("count_mergers.tex", _t)

# Table A.8: drop the comment lines the producer writes at the top of the fragment.
_src = os.path.join(SRC_DIR, "separationmerger.tex")
_t = io.open(_src, encoding="utf-8").read()
_t = "\n".join(l for l in _t.splitlines() if not l.lstrip().startswith("%"))
# the paper indents the two destination rows under "Leave Firm"
for _lab in ("Left Industry", "Join a Different Firm"):
    _t = re.sub(r"(?m)^" + _lab + r"\b", r"\\tab " + _lab, _t)
write("separationmerger.tex", _t)
