# IRTK installation
PATH="/vol/biomedic/users/$USER/bin:$PATH"
LD_LIBRARY_PATH="/vol/biomedic/users/$USER/lib"

# input settings
topdir="$appdir"                 # top-level/working directory
imgdir='../images'               # anatomical brain images
lbldir='../labels'               # input tissue and structure segmentations
bgvalue=0                        # background value of skull-stripped images

# reference for global normalization
refdir='etc'                     # directory of reference image
refid='serag-40'                 # ID of reference image (optional)
                                 #
                                 # Set reference ID to empty string to compute age-
                                 # specific affine subject-to-template transformations
                                 # from affine transformations between all image pairs.

# kernel regression
epsilon=0.001                    # kernel weight threshold
[ -n "$sigma" ] || sigma=0.5     # (default) standard deviation of Gaussian
kernel="etc/kernel_sigma=$sigma" # directory containing temporal kernel files

# output settings
bindir='bin'                     # job executable files
libdir='lib'                     # dependencies of job executables
dagdir='dag'                     # DAG files for HTCondor DAGMan job
logdir='log'                     # log files written by HTCondor jobs
dofdir='../dofs'                 # transformations computed during atlas construction
update='false'                   # enable (true) or disable update of existing DAG files

# HTCondor settings
notify_user="${USER}@imperial.ac.uk"
notification='Error'
requirements='Arch == "X86_64" && OpSysShortName == "Ubuntu" && OpSysMajorVer == 14'
log='condor.log'
