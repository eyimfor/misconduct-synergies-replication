"""Build the disclosure-category and closing-date panels for the Figure A.3 Panel B estimation."""
from pathlib import Path
import json
import numpy as np
import pandas as pd
import pyreadstat

# Load the base frame and start the construction audit
R=Path(__file__).resolve().parent
O=R/'results'
base,_=pyreadstat.read_dta(O/'base_frame.dta')
assert not base.duplicated(['id','treated','year_aum']).any()   # structural
print('base rows:', len(base))
audit={'base_rows':len(base),'base_cohorts':int(base.cohort.nunique()),'unobserved_outcomes_imputed':False}


# ---- Disclosure-category panel ----

# Disclosure totals without employment separations after allegations, on the package's
# employee-record population
event_cols=['b_crd_number','year_disclosure','any_intensity','egan_intensity','sep_after_alleg',
]
disc,_=pyreadstat.read_dta(R/'2023/data/output/adviser_disclosures.dta',usecols=event_cols)
assert disc[event_cols].notna().all().all()
disc['annual_all_nosep']=disc.any_intensity-disc.sep_after_alleg
disc['annual_ems_nosep']=disc.egan_intensity-disc.sep_after_alleg
source_cols=['any_intensity','egan_intensity','annual_all_nosep','annual_ems_nosep']
assert (disc[source_cols]>=0).all().all()

# Sum to adviser-year, then to three-year rolling totals (current year and two prior)
annual=disc.groupby(['b_crd_number','year_disclosure'],as_index=False)[source_cols].sum().rename(columns={'year_disclosure':'year'})
pieces=[]
for offset in [0,1,2]:
    x=annual[['b_crd_number','year','any_intensity','egan_intensity','annual_all_nosep','annual_ems_nosep']].copy()
    x['year']+=offset
    pieces.append(x)
rolling=pd.concat(pieces).groupby(['b_crd_number','year'],as_index=False).sum().rename(columns={
    'any_intensity':'check_all_three','egan_intensity':'check_ems_three',
    'annual_all_nosep':'all_nosep_three','annual_ems_nosep':'ems_nosep_three'})

# Combine annual and rolling counts; the check_* columns must reproduce the package's counts
counts=annual[['b_crd_number','year','any_intensity','egan_intensity']].rename(columns={
    'any_intensity':'check_all_annual','egan_intensity':'check_ems_annual'}).merge(rolling,on=['b_crd_number','year'],how='outer',validate='1:1').fillna(0)
outcomes=['all_nosep_three','ems_nosep_three']
checks={'any_intensity':'check_all_annual','egan_intensity':'check_ems_annual','any_intensity_sum':'check_all_three','egan_intensity_sum':'check_ems_three'}
sum_cols=outcomes+list(checks.values())

# Attach counts to each employee record of the real and pseudo event panels, in chunks,
# count mismatches against the package's own counts, and sum to cohort-year
chunks=[];match_audit=[]
for treated,name in [(1,'event_panel_real.dta'),(0,'event_panel_pseudo.dta')]:
    allowed=base.loc[base.treated==treated,['id','year_aum']].rename(columns={'year_aum':'year'})
    violations={key:0 for key in checks}
    employee_rows=0
    for frame,meta in pyreadstat.read_file_in_chunks(pyreadstat.read_dta,R/'2023/data/output_robust'/name,
                    chunksize=500000,usecols=['id','b_crd_number','year']+list(checks)):
        frame=frame.merge(allowed,on=['id','year'],how='inner',validate='m:1')
        if frame.empty:continue
        frame=frame.merge(counts,on=['b_crd_number','year'],how='left',validate='m:1')
        frame[sum_cols]=frame[sum_cols].fillna(0)
        for old,new in checks.items():
            violations[old]+=int((np.abs(frame[old]-frame[new])>1e-7).sum())
        frame['employee_records']=1
        part=frame.groupby(['id','year'],as_index=False)[sum_cols+['employee_records']].sum()
        part['treated']=treated
        chunks.append(part)
        employee_rows+=len(frame)
    match_audit.append({'treated':treated,'employee_rows':employee_rows,'package_count_mismatches':violations})
    print(f'Aggregated group {treated}: {employee_rows} employee records; checks {violations}',flush=True)
audit['category_rebuild']=match_audit
assert all(all(v==0 for v in r['package_count_mismatches'].values()) for r in match_audit),'Event flags do not recover package disclosure counts; inspect before estimating.'

# Convert sums to rates per 100 employee records and link to the base frame
rates=pd.concat(chunks).groupby(['id','treated','year'],as_index=False)[sum_cols+['employee_records']].sum()
for name in sum_cols:rates[name]=100*rates[name]/rates.employee_records
rates=rates.rename(columns={'year':'year_aum'})
category=base.merge(rates,on=['id','treated','year_aum'],how='left',validate='1:1',indicator=True)
audit['category_linked_rows']=int((category['_merge']=='both').sum())
assert (category['_merge']=='both').all()
assert np.allclose(category.employees,category.employee_records)
category.drop(columns=['_merge']).to_stata(O/'category_panel.dta',write_index=False,version=118)


# ---- Closing-date panel ----

# Event dating: give the real deal's announcement and closing dates to the whole matched cohort
keys=['target_crd','acquirer_crd','acquired_year']
deals,_=pyreadstat.read_dta(R/'2023/data/output/merger_sample.dta')
deals=deals.rename(columns={'acquirercrds':'acquirer_crd','mergeryear':'acquired_year'})
assert not deals.duplicated(keys).any()
dates=base.loc[base.treated==1,['id','cohort']+keys].drop_duplicates().merge(deals[keys+['announced_date','closed_date']],on=keys,how='left',validate='1:1')

# A closing date is valid when it falls on or after the announcement and in 2011-2020
ann=pd.to_datetime(dates.announced_date,format='mixed',errors='coerce')
close=pd.to_datetime(dates.closed_date,format='mixed',errors='coerce')
dates['close_year']=close.dt.year
dates['date_valid']=((close>=ann)&dates.close_year.between(2011,2020)).astype(int)
dates['close_parseable']=close.notna().astype(int)

# Event time relative to the closing year; keep valid cohorts within three years of closing
timing=base.merge(dates[['id','close_year','date_valid','close_parseable']],on='id',how='left',validate='m:1')
timing['close_time']=timing.year_aum-timing.close_year
timing['post_close']=(timing.close_time>=0).astype(int)
timing['timing_sample']=((timing.date_valid==1)&timing.close_time.between(-3,3)).astype(int)
selected=timing.loc[timing.timing_sample==1]

# Record the timing audit and write the panel and audit files
audit['timing']={'date_valid_cohorts':int(dates.loc[dates.date_valid==1,'id'].nunique()),
    'common_rows':len(selected),'common_cohorts':int(selected.id.nunique()),
    'events_with_year_change':int(dates.loc[(dates.date_valid==1)&(dates.close_year!=dates.acquired_year),'id'].nunique()),
    'rows_with_changed_post':int((selected.post!=selected.post_close).sum())}
timing.to_stata(O/'timing_panel.dta',write_index=False,version=118)
(O/'construction_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'base_rows':len(base),'category_linked_rows':audit['category_linked_rows'],'timing':audit['timing']},indent=2),flush=True)
