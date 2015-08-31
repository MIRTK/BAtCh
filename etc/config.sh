# IRTK installation
OPT="/vol/biomedic/users/$USER"
PATH="$OPT/bin:$PATH"
LD_LIBRARY_PATH="$OPT/lib:$OPT/mcr/v83/runtime/glnxa64:$OPT/mcr/v83/bin/glnxa64:$OPT/mcr/v83/sys/os/glnxa64"

# input settings -- directory structure of Emma's dHCP NeoSeg working directory
topdir="$appdir"                 # top-level/working directory
pardir='etc'                     # directory containing configuration files
imgdir='../brain'                # anatomical brain images
imgpre=''                        # image file name prefix
imgsuf='_brain.nii.gz'           # image file name suffix
lbldir='../segmentations'        # input tissue segmentations
lblpre=''                        # tissue segmentation file name prefix
lblsuf='_tissue_labels.nii.gz'   # tissue segmentation file name suffix
segdir='../segmentations'        # input structural segmentations
segpre=''                        # structural segmentation file name prefix
segsuf='_all_labels.nii.gz'      # structural segmentation file name suffix
bgvalue=0                        # background value of skull-stripped images

# reference for global normalization
refdir="$pardir"                 # directory of reference image
refpre=''                        # reference image file name prefix
refsuf='.nii.gz'                 # reference image file name suffix
refid='serag-40'                 # ID of reference image (optional)
                                 #
                                 # Set reference ID to empty string to compute age-
                                 # specific affine subject-to-template transformations
                                 # from affine transformations between all image pairs.

# kernel regression
epsilon=0.001                    # kernel weight threshold
[ -n "$sigma" ] || sigma=1       # (default) standard deviation of Gaussian
kernel="$pardir/kernel_sigma=$sigma" # directory containing temporal kernel files

# deformable registration
bending=0.005                    # weight of bending energy term
jacobian=0                       # weigth of Jacobian-based penalty term

# output settings
voxelsize=(.5 .5 .5)             # voxel size of output images
bindir='bin'                     # job executable files
libdir='lib'                     # dependencies of job executables
dagdir='dag'                     # DAG files for HTCondor DAGMan job
logdir='log'                     # log files written by HTCondor jobs
dofdir='../dofs'                 # transformations computed during atlas construction
outdir='..'                      # top level directory of output atlas files
update='false'                   # enable (true) or disable update of existing DAG files

# HTCondor settings
notify_user="${USER}@imperial.ac.uk"
notification='Error'
requirements='Arch == "X86_64" && OpSysShortName == "Ubuntu" && OpSysMajorVer == 14'
log='condor.log'
