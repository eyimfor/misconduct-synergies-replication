********************************************************************************
* Standard errors are clustered by acquiring firm, as stated in the paper.
* Exhibits: Table V standard errors and stars; Table VI clusters on the same key.
********************************************************************************

* Build the cluster identifier from the acquirer CRD
    egen clustervar = group(acquirer_crd)
