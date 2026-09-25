"""Helper functions for the group-comparison summary tables (Tables II, VII and VIII):
means by group, standardized differences and cluster-robust t-statistics."""
import numpy as np
import pandas as pd
from math import sqrt
import scipy.stats as stats
import statsmodels.formula.api as sm
import warnings
warnings.filterwarnings('ignore')


def table_by_group(df, byvar, Column_names, cluster_vars, labels,
columns_final = ['Broker-Years', 'Mean', 'Std. Dev.','Broker-Years', 'Mean', 'Std. Dev.', 'N Difference', 'T-statistic']
):
    '''
    Returns summary statistics by group with standardized difference in means and cluster adjusted t-stats
    Reorder columns and labels to produce table in specified order
    
    '''
    # Describe each variable by group
    Column_names.append(byvar[0])
    df = df[Column_names]
    df.dropna(inplace=True)
    diff_means = df.groupby(byvar).describe(include='all').T.unstack()
    Column_names.remove(byvar[0])

    # Select count, mean and standard deviation for each group
    select_diff = diff_means[[(0,'count'),(0,'mean'), (0,'std'), (1,'count'), (1,'mean'),(1,'std')]]

    # Standardized difference in means (pooled standard deviation)
    def cohen(desc_output, var):
        """ Takes pd.describe output and a variable and returns the standardized difference in means
            between the two groups (pooled standard deviation)
        """
        nx = desc_output[(1,'count')][var]
        ny = desc_output[(0,'count')][var]
        dof = nx + ny - 2
        stnd_diff = (desc_output[(1,'mean')][var] - desc_output[(0,'mean')][var])\
        /sqrt(((ny-1)*desc_output[(0,'std')][var]** 2 + (nx-1)*desc_output[(1,'std')][var]** 2)/dof)
        return ("{:.2f}".format(stnd_diff))

    # Cluster-robust t-statistic for a difference in means; if the fit fails,
    # retry on the rows where var is not missing
    def tstat_clustered(df, byvar, var, cluster_vars):
        """ Takes a dataframe and a by variable and returns the cluster-robust t-statistic
            for a difference in means test
        """
        try:
            t_stat_clus = sm.ols(str(var)+' ~ '+str(byvar[0]), data = df).fit(cov_type='cluster', cov_kwds={'groups': np.array(df[cluster_vars])}
                                                             , use_t = True, skip_mismatch=False).tvalues[1]
        except:
            df = df[df[var].notnull()]
            t_stat_clus = sm.ols(str(var)+' ~ '+str(byvar[0]), data = df).fit(cov_type='cluster', cov_kwds={'groups': np.array(df[cluster_vars])}
                                                             , use_t = True, skip_mismatch=False).tvalues[1]
        return ("{:.2f}".format(t_stat_clus))

    # Significance stars for a t-statistic
    def add_stars(value, df):
        """Append significance stars to a t-statistic (two-sided, N-2 degrees of freedom)."""
        pval = stats.t.sf(np.abs(float(value)), (len(df) - 2))*2
        if pval < 0.01:
            star = str(value)+'\sym{***}'
        elif pval < 0.05:
            star = str(value)+'\sym{**}'
        elif pval < 0.10:
            star = str(value)+'\sym{*}'
        else:
            star = str(value)
        return (star)

    # Collect standardized differences in means and clustered t-statistics
    diff_means = []
    t_stats = []
    for var in select_diff.index:
        diff_means.append(cohen(select_diff, str(var)))
        t_stats.append(tstat_clustered(df.reset_index(), byvar ,str(var), cluster_vars))

    # Rename columns to <statistic>_<group>
    select_diff.columns = [col[1]+"_"+str(col[0]) for col in select_diff.columns]

    # Add standardized differences in means and t-statistics
    select_diff['N Difference'] = diff_means
    select_diff['T-statistic'] = t_stats

    # Add stars to t-statistics
    for x in select_diff.index:
        select_diff.loc[x,'T-statistic'] = add_stars(select_diff.loc[x,'T-statistic'],
                                                                  df.notna())

    # Format counts with thousands separators and round means and standard deviations
    select_diff['count_0.0'] = select_diff['count_0.0'].astype(int).apply(lambda x : "{:,}".format(x))
    select_diff['count_1.0'] = select_diff['count_1.0'].astype(int).apply(lambda x : "{:,}".format(x))
    for col in ['mean_0.0', 'std_0.0', 'mean_1.0', 'std_1.0']:
        select_diff[col] = select_diff[col].astype(float).round(2)

    # Label variables and set the final column names
    dict_labels_inter = dict(zip(Column_names, labels))
    select_diff.rename(index =dict_labels_inter, inplace = True)
    select_diff.columns = columns_final
    return (select_diff)
