# ******************************************************************************
# Prepares the Figure A.3 Panel A estimation folder: copies the adviser-level
# inputs, the shared rules and the ado files from the package, extracts the
# Table IX block, and writes the baseline driver (baseline_frame.do) and
# preparation.json.
# ******************************************************************************
from pathlib import Path
import shutil,hashlib,json,os

# Package root (source) and this folder (destination)
SRC=Path(os.environ['FIGA3_PKG'])
RUN=Path(__file__).resolve().parent


def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda:f.read(8*1024*1024),b''):h.update(chunk)
    return h.hexdigest()


# Create the working folders
for sub in ['2023/data/output','2023/data/output_robust','2023/tables','logs','code','results']:(RUN/sub).mkdir(parents=True,exist_ok=True)

# Copy the shared rules and the ado files in environment/, which the Table IX
# block calls
for sub in ['_rules', '_helpers', 'environment']:
    shutil.copytree(SRC/sub,RUN/sub,dirs_exist_ok=True)

# Copy the input datasets and record the source and copy hashes
inputs=['2023/data/output/adviser_event_panel.dta','2023/data/output/merger_pairs_long.dta','2023/data/output/merger_sample.dta','2023/data/output_robust/event_panel_real.dta','2023/data/output_robust/event_panel_pseudo.dta']
records=[]
for rel in inputs:
    shutil.copy2(SRC/rel,RUN/rel)
    records.append({'path':rel,'bytes':(SRC/rel).stat().st_size,'source_sha256':sha(SRC/rel),'copy_sha256':sha(RUN/rel)})

# Extract the Table IX block: from the last load of adviser_event_panel to the esttab call
# that writes post_misc_regs.tex, including its /// continuation lines
source='CreateTables/pseudo_real_merger_test.do'
lines=(SRC/source).read_text(encoding='utf-8').splitlines(keepends=True)
_start = max(i for i, l in enumerate(lines)
             if l.strip().startswith('use data/output/adviser_event_panel'))
_end = next(i for i, l in enumerate(lines)
            if i > _start and 'esttab' in l and 'post_misc_regs.tex' in l)
while lines[_end].rstrip().endswith('///'):
    _end += 1
block = ''.join(lines[_start:_end + 1])
assert 'esttab' in block and 'interaction' in block, 'Table IX block not located'
(RUN/'code/table_ix_block.do').write_text(block, encoding='utf-8', newline='')

# Write the baseline driver: run the Table IX block, check the frame and save it
root=RUN.as_posix()
_n_check = 'display "BASELINE_N=" _N'
driver=f'''clear all
set more off
set linesize 180
set processors 2
global PKG "{root}"
// the shared rules address each other as $PKG/_rules/...; this estimation runs Stata
// without _config.do, so PKG has to be set here or those calls resolve to /_rules
sysdir set PLUS "{root}/environment/ado_plus"
sysdir set PERSONAL "{root}/environment/ado_personal"
adopath ++ "{root}/environment/ado_shim"
cd "{root}/2023"
log using "{root}/logs/baseline_frame_result.log", text replace
capture noisily do "{root}/code/table_ix_block.do"
local run_rc = _rc
display "BASELINE_RC=" `run_rc'
if `run_rc' != 0 exit `run_rc'
{_n_check}
isid id treated event_time
assert year_aum == acquired_year + event_time
gen long base_row = _n
save data/output/base_transformed, replace
display "BASELINE_SAVED_N=" _N
display "RUN_FINISHED=1"
log close
exit, clear
'''
(RUN/'baseline_frame.do').write_text(driver,encoding='utf-8')

# Record the inputs, the source block's location and the hashes
(RUN/'preparation.json').write_text(json.dumps({'inputs':records,'source_block':source,'source_sha256':sha(SRC/source),'block_lines':[_start+1,_end+1],'block_sha256':sha(RUN/'code/table_ix_block.do')},indent=2),encoding='utf-8')
print('Wrote the Table IX baseline driver and copied the adviser-level inputs.')
