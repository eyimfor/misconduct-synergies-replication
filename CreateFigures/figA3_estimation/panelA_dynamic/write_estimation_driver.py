# ******************************************************************************
# Writes estimate_panelA.do, the Stata driver for the Figure A.3 estimates: the
# event-time paths and the static Table IX specifications, each coefficient
# posted to results/estimates.dta.
# ******************************************************************************
from pathlib import Path

RUN=Path(__file__).resolve().parent
root=RUN.as_posix()

# Driver preamble: set up Stata, load the analysis data, winsorize and open the results file
_n_check = 'display "ANALYSIS_N=" _N'
driver=f'''clear all
set more off
set linesize 180
set processors 2
sysdir set PLUS "{root}/environment/ado_plus"
sysdir set PERSONAL "{root}/environment/ado_personal"
adopath ++ "{root}/environment/ado_shim"
cd "{root}/2023"
log using "{root}/logs/panelA_result.log", text replace
display "Figure A.3 Panel A estimation"
use data/output/panelA_analysis, clear
{_n_check}
isid id treated event_time
assert year_aum == acquired_year + event_time
* Winsorize the one-count-per-adviser rates at the pooled 1st and 99th percentiles.
winsor2 unique_all_rate unique_ems_rate, cut(1,99) replace
tempname result_handle
postfile `result_handle' str32 specification str8 outcome str16 term double N double N_clusters double df_r double coefficient double se double t double p double lower95 double upper95 using "{root}/results/estimates.dta", replace
'''


# Stata code that posts one coefficient with its standard error, t, p and 95% interval
def post_term(spec,outcome,term):
    return f'''scalar bval = _b[{term}]
scalar seval = _se[{term}]
scalar tval = bval/seval
scalar pval = 2*ttail(e(df_r),abs(tval))
scalar crit = invttail(e(df_r),0.025)
post `result_handle' ("{spec}") ("{outcome}") ("{term}") (e(N)) (e(N_clust)) (e(df_r)) (bval) (seval) (tval) (pval) (bval-crit*seval) (bval+crit*seval)
'''


# Panel A: event-time paths for Employee Disclosure (All), all cohorts and clean cohorts
variants=[('dynamic_full',''),('dynamic_clean','if clean_event == 1')]
terms=['te_m3','te_m2','te_0','te_p1','te_p2','te_p3']
for spec,sample in variants:
    for outcome,var in [('All','fraction_bad_a_flow')]:
        driver+=f'''\ndisplay "BEGIN_MODEL={spec}_{outcome}"
reghdfe {var} {' '.join(terms)} {sample}, absorb(unit_id id#year_aum) vce(cluster cohort)
display "MODEL_N=" e(N) " CLUSTERS=" e(N_clust) " DF_R=" e(df_r)
'''
        for term in terms:driver+=post_term(spec,outcome,term)
        driver+=f'display "END_MODEL={spec}_{outcome}"\n'

# Panel B, first two rows: the Table IX specification, with the Table IX outcome and with each
# adviser counted once per pair-year
for spec,variables in [('static_record_rate',[('All','fraction_bad_a_flow'),('EMS','fraction_bad_e_flow')]),('static_unique_adviser_rate',[('All','unique_all_rate'),('EMS','unique_ems_rate')])]:
    for outcome,var in variables:
        driver+=f'''\ndisplay "BEGIN_MODEL={spec}_{outcome}"
reghdfe {var} interaction treated post both_retailc ln_aum_std ln_age_z ln_employees_std, absorb(year_aum) vce(cluster cohort)
'''+post_term(spec,outcome,'interaction')+f'display "END_MODEL={spec}_{outcome}"\n'

# Close the results file and write the driver
driver+=f'''\npostclose `result_handle'
display "RUN_FINISHED=1"
log close
exit, clear
'''
(RUN/'estimate_panelA.do').write_text(driver,encoding='utf-8')
print('Wrote estimate_panelA.do.')
