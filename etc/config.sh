# IRTK installation
PATH="/vol/biomedic/users/$USER/local/linux-3.6/irtk-nnatlas:$PATH"
LD_LIBRARY_PATH="/vol/biomedic/users/$USER/local/lib"

# input settings
topdir="$appdir"                 # top-level/working directory
imgdir='../images'               # anatomical brain images
lbldir='../labels'               # input tissue and structure segmentations
bgvalue=0                        # background value of skull-stripped images

# kernel regression
epsilon=0.001                    # kernel weight threshold
sigma=1                          # (default) standard deviation of Gaussian
kernel="etc/kernel_sigma=$sigma" # directory containing temporal kernel files

# output settings
pardir="$(dirname "$BASH_SOURCE")" # directory containing further configuration files
bindir='bin'                       # job executable files
libdir='lib'                       # dependencies of job executables
dagdir='dag'                       # DAG files for HTCondor DAGMan job
logdir='log'                       # log files written by HTCondor jobs
dofdir='../dofs'                   # transformations computed during atlas construction
update='false'                     # enable (true) or disable update of existing DAG files

# HTCondor settings
notify_user="${USER}@imperial.ac.uk"
notification='Error'
requirements='Arch == "X86_64" && OpSysShortName == "Ubuntu" && (OpSysMajorVer == 12 || OpSysMajorVer == 13)'
log='condor.log'
