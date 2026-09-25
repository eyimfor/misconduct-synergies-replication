"""Estimate Appendix Figure A.3 from package outputs.

Panel (a) comes from the panelA_dynamic chain, panel (b) from panelA_dynamic (baseline
and distinct-adviser rows) plus panelB_alternatives (separations, announcement and
closing years).
Both chains start from six files in 2023/data/output{,_robust} of the replication
package.

Usage:
  FIGA3_PKG=<package root>  FIGA3_WORK=<scratch dir>  [FIGA3_STATA=<stata exe>]
  python run_figA3.py

The package is only read. Everything is written under FIGA3_WORK. Needs about 1.6 GB there
(each chain's prepare.py copies event_panel_real.dta and event_panel_pseudo.dta).
"""
import json, os, platform, re, shutil, subprocess, sys
from pathlib import Path
import pandas as pd

# Package, scratch folder and the Stata executable for this platform
HERE = Path(__file__).resolve().parent
PKG = Path(os.environ["FIGA3_PKG"])
WORK = Path(os.environ["FIGA3_WORK"])
if platform.system() == "Windows":
    STATA = os.environ.get("FIGA3_STATA", r"C:\Program Files\Stata17\StataMP-64.exe")
    STATA_FLAG = "-e"
else:
    STATA = os.environ.get("FIGA3_STATA", "/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp")
    STATA_FLAG = "-b"


# Run a Python script in a chain folder
def py(cwd, script):
    print(">> python", cwd.name, script)
    subprocess.run([sys.executable, script], cwd=cwd, check=True,
                   env={**os.environ, "FIGA3_PKG": str(PKG)})


def stata(cwd, dofile, log, *args, done="RUN_FINISHED=1"):
    """Stata batch exits 0 on error, so the do-file's own log is the test."""
    print(">> stata", cwd.name, dofile, *args)
    subprocess.run([STATA, STATA_FLAG, "do", str(cwd / dofile), *args], cwd=cwd, check=True)
    text = (cwd / "logs" / log).read_text(errors="replace")
    errs = re.findall(r"^r\(\d+\);", text, flags=re.M)
    if errs or done not in text:
        sys.exit(f"STATA FAILED {dofile}: errors={errs}, see {cwd / 'logs' / log}")


# Copy a chain folder's files into the scratch folder
def stage(name):
    dst = WORK / name
    dst.mkdir(parents=True, exist_ok=True)
    for f in (HERE / name).iterdir():
        if f.is_file():
            shutil.copy2(f, dst / f.name)
    return dst


# Run both chains, then write each chain's estimates to JSON under FIGA3_WORK
def main():
    # Panel (a) chain
    pa = stage("panelA_dynamic")
    py(pa, "prepare.py")
    stata(pa, "baseline_frame.do", "baseline_frame_result.log")
    py(pa, "build_analysis_data.py")
    py(pa, "write_estimation_driver.py")
    stata(pa, "estimate_panelA.do", "panelA_result.log")

    # Panel (b) alternatives chain
    pb = stage("panelB_alternatives")
    py(pb, "prepare.py")
    stata(pb, "prepare_frame.do", "base_frame_result.log", done="BASE_FRAME_FINISHED=1")
    py(pb, "build_panelB_data.py")
    stata(pb, "estimate_panelB.do", "panelB_result.log", pb.as_posix())

    # _3_figA3_plot.py draws from panelA_estimates.json and panelB_estimates.json
    for name, src in (("panelA_estimates.json", "panelA_dynamic"),
                      ("panelB_estimates.json", "panelB_alternatives")):
        est = pd.read_stata(WORK / src / "results/estimates.dta")
        (WORK / name).write_text(json.dumps(
            {"source": src, "estimates": est.to_dict(orient="records")},
            indent=1, default=str))
        print("wrote", name, f"({len(est)} estimates)")


if __name__ == "__main__":
    main()
