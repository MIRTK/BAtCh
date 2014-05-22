Overview
========

HTCondor DAGMan application for the consistent construction of a spatio-temporal
brain atlas and growth model from cross-sectional brain MR images and automatic
tissue and structure segmentations.

Configuration Files
===================

The atlas construction workflow is configured by mainly three files:

- **etc/config.sh**: A shell script containing global variables used by **setup**.
- **etc/age.csv**:   A comma or space separated CSV file with image IDs and corresponding ages.
- **etc/sub.lsl**:   An optional subject list containing only the IDs of those images
                     from which the spatio-temporal atlas should be created.

Temporal Regression Kernels
===========================

The atlas construction workflow produces a spatial anatomical atlas and
tissue/structure probability maps for each time point for which a temporal kernel
is found in the **krldir** directory specified in **etc/config.sh**.

The kernels used for the neonatal atlas are based on a Gaussian function with
mean corresponding to the desired atlas time point (gestational age, GA) and a
constant standard deviation (default 1 week GA). A variable kernel width is
possible by generating kernels with varying standard deviation for different
atlas time points. A input "kernel" is simply a comma or space separated CSV
file, where the first column contains the ID of the images from which the
atlas at the respective time point is created and the second column the
respective kernel weight. The provided **lib/kernel** script can be used to
create such CSV files using a Gaussian kernel function. It should be noted,
however, that the kernels can be generated with any tool, including MATLAB.

For example, the kernels for the neonatal atlas build from 420 images for the
age range 28 to 44 weeks GA, with a temporal resolution of 1 week, were generated
by setting the `sigma=1` in the **etc/config.sh** file and then running the command

```shell
lib/kernel -range 28 44 -dt 1
```

Generate Workflow DAG
=====================

Given the **age.csv** (and **sub.lst**) as well as the temporal regression kernels
generated in the previous step, execute the **setup** script to generate the
HTCondor and DAGMan files which specify the separate jobs to be executed by
HTCondor and describe the directed acyclic graph (DAG) of the workflow
(i.e., job dependencies). The setup script will also copy the used IRTK commands
into the configured *bindir* to ensure these are not modified while the workflow
is being executed. The generated DAG files, parameter files, and job descriptions
can be found in the configured **dagdir**.

```shell
./setup
```

Workflow Execution
==================

The atlas construction workflow can be executed by simply submitting the
**$dagdir/main.dag** to HTCondor using **condor_submit_dag**. However, as the
DAGMan job will run for a long time which requires the periodic renewal of the
obtained Kerberos v5 ticket granting ticket (TGT) used to authenticate with
HTCondor which allows DAGMan to submit pending jobs of the workflow, it is
recommended to execute the **runme** script instead. This script will obtain
a valid Kerberos ticket and copy the ticket cache to **etc/krb5cc**. It overrides
the DAGMan generated HTCondor submit script to use a shell script as executable
which runs **condor_dagman** using **krenew** instead.

```shell
./runme
```

**TODO:** The renewal of the Kerberos ticket still does not work and the DAGMan
          job fails to submit pending jobs when it is running longer than the
          expiration/life time of the Kerberos ticket obtained when submitting
          the DAGMan job.