# MIRTK installation
if [ -z "$MIRTK_DIR" ]; then
  MIRTK_DIR=`which mirtk`
  if [ $? -ne 0 ]; then
    echo "Could not find MIRTK, either set PATH or MIRTK_DIR in $BASH_SOURCE" 1>&2
    exit 1
  fi
  MIRTK_DIR="`cd "`dirname "$MIRTK_DIR"`"/.. && pwd`"
fi

PATH="$appdir/bin:$MIRTK_DIR/lib/tools:$MIRTK_DIR/lib/mirtk/tools:$PATH"
LD_LIBRARY_PATH="$appdir/lib:$MIRTK_DIR/lib:$MIRTK_DIR/lib/mirtk:$LD_LIBRARY_PATH"

export PATH LD_LIBRARY_PATH


# default input settings
topdir="`cd $appdir && pwd`"          # absolute path of top-level working directory

pardir="`dirname "$BASH_SOURCE"`"     # directory containing configuration files
pardir="`cd $pardir && pwd`"          # - make path absolute
pardir="${pardir/$topdir\//}"         # - make path relative to working directory

agelst="$pardir/ages.csv"             # CSV table of image IDs and associated ages
sublst="$pardir/subjects.lst"         # List of image IDs, one per line

imgdir='../images'                    # directory of anatomical brain images
imgpre=''                             # brain image file name prefix
imgsuf='.nii.gz'                      # brain image file name suffix
bgvalue=0                             # background value of skull-stripped images

lbldir='../labels'                    # base directory of available segmentations
lblpre='structures/'                  # file name prefix of structural segmentation label image
lblsuf='.nii.gz'                      # file name suffix of structural segmentation label image
clspre='tissues/'                     # file name prefix of tissue segmentations
clssuf='.nii.gz'                      # file name suffix of tissue segmentations
tissues=9                             # no. of tissue classes
structures=87                         # no. of structures

segdir='../masks'                     # directory with binary segmentation masks
segpre=''                             # file name prefix of binary segmentation masks
segsuf='.nii.gz'                      # file name suffix of binary segmentation masks

# default reference for global normalization
refdir="etc/reference"                # directory of reference image
refpre=''                             # reference image file name prefix
refsuf='.nii.gz'                      # reference image file name suffix
refid=''                              # ID of reference image (optional)
                                      # - set reference ID to empty string to compute
                                      #   population specific linear average
refini='false'                        # - false: use reference for global normalization
                                      # - true:  construct linear population reference
                                      #          and, when refid set, align this average
                                      #          image with the specified reference

# default workflow parameters
verbose=0                             # verbosity of output messages
resolution=1                          # highest image resolution at final level in mm
interpolation='Linear'                # image interpolation mode
similarity='NCC'                      # image (dis-)similarity measure: SSD, NMI, NCC
spacing=2.5                           # control point spacing on finest level
bending=0.001                         # weight of bending energy term
jacobian=0.01                         # weigth of Jacobian-based penalty term
refine=1                              # no. of template refinement steps
threads=8                             # maximum no. of CPU cores to use
epsilon=0.001                         # kernel weight threshold
means=()                              # default list of atlas time points
sigma=1                               # default standard deviation of temporal kernel
kernel="$pardir/weights"              # directory containing temporal kernel files
update='false'                        # enable (true) or disable update of existing DAG files
binlnk='true'                         # link (true) or copy (false) job executables

# default output settings
libdir="lib"                          # shared libraries required by job executables
bindir="$libdir/tools"                # symbolic links to / copy of job executable files
dagdir='dag'                          # workflow description as DAG files for HTCondor DAGMan
logdir='log'                          # directory of log files written by workflow jobs
dofdir='../dofs'                      # transformations computed during atlas construction
evldir='../eval'                      # directory of evaluation output files
outdir='../atlas'                     # atlas output directory

# default HTCondor settings
notify_user="${USER}@ic.ac.uk"
notification='Error'
requirements='Arch == "X86_64" && OpSysShortName == "Ubuntu" && OpSysMajorVer == 14'
log='condor.log'

# utility function to set pardir in custom configuration
set_pardir_from_file_path()
{
  pardir="`dirname "$1"`"
  if [ -L "$1" ]; then
    pardir="$pardir/`readlink "$1"`"
    pardir="`dirname "$pardir"`"
  fi
  pardir="`cd $pardir && pwd`"
  pardir="${pardir/$topdir\//}"
}

# load default custom configuration
# (e.g., link to configuration otherwise specified with -config option of commands)
if [ -f "$topdir/$pardir/custom.sh" ]; then
  source "$topdir/$pardir/custom.sh"
fi
