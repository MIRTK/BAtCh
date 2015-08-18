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

Workflow Execution
==================

The atlas construction workflow can be executed by simply submitting the
**$dagdir/main.dag** to HTCondor using **condor_submit_dag**. However, as the
DAGMan job will run for a long time which requires the periodic renewal of the
obtained Kerberos v5 ticket granting ticket (TGT) used to authenticate with
HTCondor such that DAGMan can submit pending jobs of the workflow, it is
recommended to execute the **runme** script instead:

```shell
./runme
```

This script will replace the *condor_dagman* executable usually submitted to
HTCondor by a Bash script named **$bindir/dagman** which runs *condor_dagman* as
background job and periodically reinitializes the Kerberos ticket cache using **kinit**.
It therefore requires the password of the user who runs DAGMan. The runme script
thus queries this password and writes it (plain text!) to the **dagman** Bash script.
To circumvent exposure of the password, the Bash script is made read and executable
only by the user who executed the runme script.

An alternative approach uses **krenew** which does not require a user password
to be available to the *dagman* script, but is only suitable if the maximum
renewable lifetime of a TGT is longer than the expected runtime of the DAGMan
job. At the moment, this is not the case at Imperial's DoC, where the maximum
lifetime is only 10 hours.

Another, and possibly better, option is to set up a cron job that periodically
obtains a new Kerberos ticket. Details on how this can be setup at DoC are
available to BioMedIA members at
http://biomedic.doc.ic.ac.uk/index.php?n=Internal.KerberosTickets.

The transformations computed during the atlas construction are written to
subdirectories within the configured **dofdir** (default: **../dofs**) and the
final atlas data is written to the configured **outdir** (default: **../atlas**).
