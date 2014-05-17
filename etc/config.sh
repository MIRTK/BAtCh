# IRTK installation
IRTK_DIR='/vol/biomedic/users/as12312/local/linux-3.6/irtk-nnatlas'
LIBRARY_PATH='/vol/biomedic/users/as12312/local/lib'

# input settings
topdir="$PWD"          # top-level/working directory
imgdir='images'        # anatomical brain images
lbldir='labels'        # input tissue and structure segmentations
bgvalue=0              # background value of skull-stripped images

# output settings
bindir='workflow/bin'  # job executable files
libdir='workflow/lib'  # dependencies of job executables
dagdir='workflow/dags' # DAG files for HTCondor DAGMan job
moddir='workflow/mods' # DAG nodes, i.e., HTCondor job description + PRE/POST scripts
pardir='workflow/pars' # HTCondor job parameters
logdir='workflow/logs' # log files written by HTCondor jobs
dofdir='dofs'          # transformations computed during atlas construction

# HTCondor settings
notify_user='as12312@imperial.ac.uk'
notification='Error'
requirements='Arch == "X86_64" && OpSysShortName == "Ubuntu" && (OpSysMajorVer == 12 || OpSysMajorVer == 13)'
log="workflow/htcondor.log"
