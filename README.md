HTCondor DAGMan application for the construction of a spatio-temporal brain atlas
and growth model from cross-sectional brain MR images.

Initial Setup
=============

Clone this repository into a **workflow** subdirectory next to the directories
containing the individual MR images and corresponding segmentation label maps.
For example, run the following commands to create a new directory for the
construction of a new brain atlas.

```shell
mkdir BrainAtlas && cd BrainAtlas
ln -s <path_to_images> images
ln -s <path_to_labels> labels
git clone git@gitlab.doc.ic.ac.uk:as12312/brain-growth-atlas-builder.git workflow
cd workflow
```

Configuration Files
===================

The atlas construction workflow is configured by mainly three files:

- **etc/config.sh**: A shell script containing global variables used by **setup**.
- **etc/age.csv**:   A comma or space separated CSV file with image IDs and corresponding ages.
- **etc/sub.lst**:   An optional subject list containing only the IDs of those images
                     from which the spatio-temporal atlas should be created.

Temporal Regression Kernels
===========================

The atlas construction workflow produces a spatial anatomical atlas and
tissue/structure probability maps for each time point for which a temporal kernel
is found in the **krldir** directory specified in **etc/config.sh**.

The kernels used for the neonatal atlas are based on a Gaussian function with
mean corresponding to the desired atlas time point (gestational age, GA) and a
constant standard deviation (default 1 week). A variable kernel width is
possible by generating kernels with varying standard deviation for different
atlas time points. An input "kernel" is simply a comma or space separated CSV
file named **weights_t=$age.csv**, where the first column contains the ID of
the images from which the atlas at the respective time point is created and the
second column the respective kernel weight. The provided **lib/kernel** script
can be used to create such CSV files using a Gaussian kernel function. It should
be noted, however, that the kernels can be generated with any tool, including MATLAB.

For example, the kernels for the neonatal atlas build from 420 images for the
age range 28 to 44 weeks GA, with a temporal resolution of 1 week, were generated
by setting `sigma=1` in the **etc/config.sh** file and then running the command

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
into the configured **bindir** to ensure these are not modified while the workflow
is being executed. The generated DAG files, parameter files, and job descriptions
can be found in the configured **dagdir**.

```shell
./setup
```

Different variants of the spatio-temporal brain atlas construction workflow
are included. To use these, call either one of the **workflow_v?** scripts
instead of **setup**. For example,

```shell
./workflow_v3 -x dag/v3 -r ref_v3 -d ../v3/dofs -o ../v3
```

This will write the HTCondor DAGMan scripts to *dag/v3*. The computed
transformation files will be stored in *../v3/dofs* and the generated
atlas files in *../v3/templates* and *../v3/pbmaps*, respectively.


Workflow Execution
==================

The atlas construction workflow can be executed by simply submitting the
**$dagdir/main.dag** to HTCondor using **condor_submit_dag**.

The long running DAGMan job needs to have a valid authentication method to
submit new jobs and monitor running jobs. The current Imperial College London
Department of Computing (DoC) HTCondor installation uses Kerberos v5
authentication. The user running the DAGMan job must periodically renew
their Kerberos ticket granting ticket (TGT). This can be done by executing
the **submit** script instead of calling **condor_submit_dag** directly:

```shell
./submit
```

This script will replace the *condor_dagman* executable usually submitted to
HTCondor by a Bash script named **$bindir/dagman** which runs *condor_dagman* as
background job and periodically reinitializes the Kerberos ticket cache using **kinit**.
To be able to do so without the user account password, it requires a user-generated
kerb5.keytab file.

Alternatively, a cron job independently of this atlas creation workflow can be setup,
which periodically obtains a new Kerberos ticket. Instructions are available to
BioMedIA members at http://biomedic.doc.ic.ac.uk/index.php?n=Internal.KerberosTickets.


Output Files
============

The transformations computed during the atlas construction are written to
subdirectories within the configured **dofdir** (default: **../dofs**) and the
final atlas data is written to the configured **outdir** (default: **..**).


References
==========

- A. Schuh, M. Murgasova, A. Makropoulos, C. Ledig, S.J. Counsell, J.V. Hajnal, P. Aljabar, D. Rueckert,
  "Construction of a 4D Brain Atlas and Growth Model using Diffeomorphic Registration",
  MICCAI STIA Workshop, LNCS Volume 8682, pp. 27-37 (2014)
