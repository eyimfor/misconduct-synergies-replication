# Builds panelA_analysis.dta, the cohort-year panel for the Appendix Figure A.3 panel (a)
# estimation, and writes results/data_audit.json.
from pathlib import Path
import pandas as pd,numpy as np,json

# Load the transformed base frame and the raw event panel; they must align row for row
RUN=Path(__file__).resolve().parent
D=RUN/'2023/data/output'
base=pd.read_stata(D/'base_transformed.dta',convert_categoricals=False)
raw=pd.read_stata(D/'adviser_event_panel.dta',convert_categoricals=False)
assert len(base)==len(raw)          # structural: the two frames must align
print('base/raw rows:', len(base))
assert not base.duplicated(['id','treated','event_time']).any()
assert (base.year_aum==base.acquired_year+base.event_time).all()

# Recover each cohort's four firms (real and pseudo target and acquirer) from the long pair file
long=pd.read_stata(D/'merger_pairs_long.dta',convert_categoricals=False)
assert not long.duplicated(['id','acquired_year','count']).any()
roles=long.pivot(index=['id','acquired_year'],columns='count',values='crd').rename(columns={0:'real_target',1:'pseudo_target',2:'pseudo_acquirer',3:'real_acquirer'}).reset_index()
roles=base[['id','acquired_year']].drop_duplicates().merge(roles,on=['id','acquired_year'],validate='1:1')
print('roles:', len(roles))
role_cols=['real_target','real_acquirer','pseudo_target','pseudo_acquirer']
for c in ['id','acquired_year']+role_cols:roles[c]=roles[c].astype(int)

# Check the roles against the target and acquirer on the base frame
orig=base.merge(roles,on=['id','acquired_year'],validate='m:1')
assert np.where(orig.treated==1,orig.real_target,orig.pseudo_target).tolist()==orig.target_crd.tolist()
assert np.where(orig.treated==1,orig.real_acquirer,orig.pseudo_acquirer).tolist()==orig.acquirer_crd.tolist()

# A cohort is clean when none of its four firms appears in another merger within three years
# of the deal (the focal real transaction excluded)
events=pd.read_stata(D/'merger_sample.dta',convert_categoricals=False)
events=events[['target_crd','acquirercrds','mergeryear']].astype(int).drop_duplicates()
exposures=[]
for row in roles.itertuples(index=False):
    firms=set(int(getattr(row,c)) for c in role_cols)
    near=events.loc[(events.mergeryear-row.acquired_year).abs()<=3]
    hit=near.loc[near.target_crd.isin(firms)|near.acquirercrds.isin(firms)]
    focal=(hit.target_crd==row.real_target)&(hit.acquirercrds==row.real_acquirer)&(hit.mergeryear==row.acquired_year)
    other=hit.loc[~focal]
    exposures.append({'id':int(row.id),'clean_event':int(other.empty),'other_transactions_in_window':int(len(other)),'other_real_role_exposure':bool(((other.target_crd.isin([row.real_target,row.real_acquirer]))|(other.acquirercrds.isin([row.real_target,row.real_acquirer]))).any()),'other_pseudo_role_exposure':bool(((other.target_crd.isin([row.pseudo_target,row.pseudo_acquirer]))|(other.acquirercrds.isin([row.pseudo_target,row.pseudo_acquirer]))).any())})
roles=roles.merge(pd.DataFrame(exposures),on='id',validate='1:1')

# For the real and pseudo panels: disclosure rates per employee record and per distinct
# adviser, checked against the package's employee counts and rates
agg_records=[];denom_audit={}
for filename,treated in [('event_panel_real',1),('event_panel_pseudo',0)]:
    # Keep the base frame's cohort-years; duplicate adviser rows must carry the same counts
    micro=pd.read_stata(RUN/f'2023/data/output_robust/{filename}.dta',columns=['id','year','b_crd_number','crd','any_intensity_sum','egan_intensity_sum'],convert_categoricals=False)
    keys=base.loc[base.treated==treated,['id','year_aum']].rename(columns={'year_aum':'year'})
    micro=micro.merge(keys,on=['id','year'],validate='m:1')
    dup=micro.loc[micro.duplicated(['id','year','b_crd_number'],keep=False)]
    disagreement={c:int((dup.groupby(['id','year','b_crd_number'])[c].nunique(dropna=False)>1).sum()) for c in ['any_intensity_sum','egan_intensity_sum']}
    assert not any(disagreement.values()),f'Duplicate disclosures disagree: {disagreement}'
    assert not micro[['any_intensity_sum','egan_intensity_sum']].isna().any().any()
    micro['any_intensity_sum']=micro.any_intensity_sum.astype(float)
    micro['egan_intensity_sum']=micro.egan_intensity_sum.astype(float)

    # Sums and rates per 100 records and per 100 distinct advisers
    per_record=micro.groupby(['id','year']).agg(record_n=('b_crd_number','size'),record_all_sum=('any_intensity_sum','sum'),record_ems_sum=('egan_intensity_sum','sum'))
    unique=micro.drop_duplicates(['id','year','b_crd_number']).groupby(['id','year']).agg(unique_n=('b_crd_number','size'),unique_all_sum=('any_intensity_sum','sum'),unique_ems_sum=('egan_intensity_sum','sum'))
    agg=per_record.join(unique).reset_index();agg['treated']=treated
    agg['raw_all_from_records']=100*agg.record_all_sum/agg.record_n
    agg['raw_ems_from_records']=100*agg.record_ems_sum/agg.record_n
    agg['unique_all_rate']=100*agg.unique_all_sum/agg.unique_n
    agg['unique_ems_rate']=100*agg.unique_ems_sum/agg.unique_n
    agg=agg.rename(columns={'year':'year_aum'})

    # The per-record rates must reproduce the package's employee counts and rates
    check=raw.loc[raw.treated==treated,['id','year_aum','employees','fraction_bad_a_flow','fraction_bad_e_flow']].merge(agg,on=['id','year_aum'],validate='1:1')
    print('check:', len(check))
    assert (check.employees==check.record_n).all()
    all_diff=(check.fraction_bad_a_flow-check.raw_all_from_records).abs()
    ems_diff=(check.fraction_bad_e_flow-check.raw_ems_from_records).abs()
    assert np.allclose(check.fraction_bad_a_flow,check.raw_all_from_records,rtol=1e-6,atol=1e-6)
    assert np.allclose(check.fraction_bad_e_flow,check.raw_ems_from_records,rtol=1e-6,atol=1e-6)
    denom_audit[filename]={'selected_micro_rows':len(micro),'distinct_adviser_rows':int(agg.unique_n.sum()),'duplicate_surplus':int((agg.record_n-agg.unique_n).sum()),'pair_years_with_duplicates':int((agg.record_n>agg.unique_n).sum()),'duplicate_count_disagreements':disagreement,'baseline_employee_count_matches':True,'max_all_rate_absolute_diff':float(all_diff.max()),'max_ems_rate_absolute_diff':float(ems_diff.max()),'baseline_raw_rates_match_with_float_tolerance':True}
    agg_records.append(agg)

# Assemble and write the analysis panel: unit ids, duplicate share, treated x event-time terms
all_agg=pd.concat(agg_records,ignore_index=True)
data=base.merge(all_agg,on=['id','year_aum','treated'],validate='1:1').merge(roles,on=['id','acquired_year'],validate='m:1')
print('data rows:', len(data))
data['unit_id']=data.id.astype(int)*2+data.treated.astype(int)
data['duplicate_share']=(data.record_n-data.unique_n)/data.record_n
for term,t in [('te_m3',-3),('te_m2',-2),('te_0',0),('te_p1',1),('te_p2',2),('te_p3',3)]:data[term]=(data.treated*(data.event_time==t)).astype(float)
for c in ['other_real_role_exposure','other_pseudo_role_exposure']:data[c]=data[c].astype('int8')
data.to_stata(D/'panelA_analysis.dta',write_index=False,version=118)

# Write the data audit: rows, cohorts and event-time support for the full and clean samples
support={name:{str(int(k)):int(v) for k,v in sub.groupby('event_time').size().items()} for name,sub in [('full',data),('clean',data[data.clean_event==1])]}
audit={'baseline_rows':len(data),'cohorts':int(data.id.nunique()),
       'clean_event_cohorts':int(data.loc[data.clean_event==1,'id'].nunique()),
       'event_time_support':support,'denominators':denom_audit}
(RUN/'results/data_audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
print(json.dumps(audit,indent=2))
