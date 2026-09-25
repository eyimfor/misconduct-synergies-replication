# ******************************************************************************
# Prepares the Figure A.3 Panel B estimation folder: copies the inputs, the
# shared rules and the ado files from the package, hash-verifies the inputs, and
# writes the base-frame driver (prepare_frame.do) and preparation.json.
# ******************************************************************************
from pathlib import Path
import hashlib,json,shutil,os

# Package root (source) and this folder (destination)
A=Path(os.environ['FIGA3_PKG'])
R=Path(__file__).resolve().parent


def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda:f.read(4<<20),b''):h.update(chunk)
    return h.hexdigest()


# Create the working folders
for folder in ['2023/data/output','2023/data/output_robust','logs','results','code']:
    (R/folder).mkdir(parents=True,exist_ok=True)

# Copy the shared rules and the ado files in environment/, which the base-frame
# driver calls
for sub in ['environment', '_rules', '_helpers']:
    shutil.copytree(A/sub,R/sub,dirs_exist_ok=True)

# Copy any input not already present and check that the copy matches the source
inputs=['2023/data/output/adviser_event_panel.dta','2023/data/output/merger_sample.dta',
        '2023/data/output/adviser_disclosures.dta',
        '2023/data/output_robust/event_panel_real.dta','2023/data/output_robust/event_panel_pseudo.dta']
records=[]
for rel in inputs:
    dst=R/rel
    if not dst.exists():shutil.copy2(A/rel,dst)
    a,b=sha(A/rel),sha(dst)
    assert a==b,rel
    records.append({'relative_path':rel,'source_sha256':a,'working_sha256':b,'bytes':dst.stat().st_size})

# Write the base-frame driver: winsorize, build the unit and pair-time ids, save base_frame.dta
root=R.as_posix()
do=f'''clear all
set more off
set processors 2
set linesize 180
global PKG "{root}"
// the shared rules address each other as $PKG/_rules/...; this estimation runs Stata
// without _config.do, so PKG has to be set here or those calls resolve to /_rules
sysdir set PLUS "{root}/environment/ado_plus"
sysdir set PERSONAL "{root}/environment/ado_personal"
adopath ++ "{root}/environment/ado_shim"
cd "{root}/2023"
log using "{root}/logs/base_frame_result.log", text replace
use data/output/adviser_event_panel, clear
do "$PKG/_rules/winsorize_last.do" ix_final "fraction_bad_a_flow fraction_bad_e_flow combined_aumg combined_clg"
isid cohort treated year_aum
egen long unit = group(cohort treated)
egen long pair_time = group(cohort year_aum)
bys pair_time: assert _N==2
save "{root}/results/base_frame.dta", replace
display "BASE_N=" _N
display "BASE_FRAME_FINISHED=1"
log close
exit, clear
'''
(R/'prepare_frame.do').write_text(do,encoding='utf-8')

# Record the source folder and the input hashes
meta={'source':str(A),'inputs':records,
      'scope':'Figure A.3 Panel B estimation inputs'}
(R/'preparation.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
print(f'Copied and hash-verified {len(inputs)} inputs; wrote base-frame driver.')
