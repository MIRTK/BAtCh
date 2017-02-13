# MIRTK installation
if [ -z "$MIRTK_DIR" ]; then
  MIRTK_DIR=$(which mirtk)
  if [ $? -ne 0 ]; then
    echo "Could not find MIRTK, either set PATH or MIRTK_DIR in $BASH_SOURCE" 1>&2
    exit 1
  fi
  MIRTK_DIR="$(cd "$(dirname "$MIRTK_DIR")"/.. && pwd)"
fi

PATH="$appdir/bin:$MIRTK_DIR/lib/tools:$MIRTK_DIR/lib/mirtk/tools:$PATH"
LD_LIBRARY_PATH="$appdir/lib:$MIRTK_DIR/lib:$MIRTK_DIR/lib/mirtk:$LD_LIBRARY_PATH"

export PATH LD_LIBRARY_PATH


# input settings
topdir="$appdir"                      # top-level working directory
pardir='etc'                          # directory containing configuration files
imgdir='../images'                    # directory of anatomical brain images
imgpre=''                             # brain image file name prefix
imgsuf='.nii.gz'                      # brain image file name suffix
lbldir='../labels'                    # base directory of available segmentations
                                      # - $lbldir/tissues/:    Tissue segmentations
                                      # - $lbldir/structures/: Structural segmentations
lblpre=''                             # label image file name prefix
lblsuf='.nii.gz'                      # label image file name suffix
segdir='../masks'                     # directory with binary segmentation masks
segpre=''                             # binary segmentation file name prefix
segsuf='.nii.gz'                      # binary segmentation file name suffix
tissues=9                             # no. of tissue classes
structures=87                         # no. of structures
bgvalue=0                             # background value of skull-stripped images

# reference for global normalization
refdir="$pardir"                      # directory of reference image
refpre=''                             # reference image file name prefix
refsuf='.nii.gz'                      # reference image file name suffix
refid='serag-40'                      # ID of reference image (optional)
                                      #
                                      # Set reference ID to empty string to compute age-
                                      # specific affine subject-to-template transformations
                                      # from affine transformations between all image pairs.

# workflow parameters
resolution=0.5                        # highest image resolution at final level in mm
similarity='NCC'                      # image (dis-)similarity measure: SSD, NMI, NCC
bending=0.005                         # weight of bending energy term
jacobian=0                            # weigth of Jacobian-based penalty term
refine=1                              # no. of template refinement steps
threads=8                             # maximum no. of CPU cores to use
epsilon=0.054                         # kernel weight threshold
[ -n "$sigma" ] || sigma=1            # (default) standard deviation of Gaussian
kernel="$pardir/kernel_sigma=$sigma"  # directory containing temporal kernel files

# output settings
bindir='bin'                          # auxiliary scripts and job executable files
libdir='lib'                          # shared libraries required by job executables
dagdir='dag'                          # workflow description as DAG files for HTCondor DAGMan
logdir='log'                          # directory of log files written by workflow jobs
dofdir='../dofs'                      # transformations computed during atlas construction
evldir='../eval'                      # directory of evaluation output files
outdir='../atlas'                     # atlas output directory
update='false'                        # enable (true) or disable update of existing DAG files

# HTCondor settings
notify_user="${USER}@imperial.ac.uk"
notification='Error'
requirements='Arch == "X86_64" && OpSysShortName == "Ubuntu" && OpSysMajorVer == 14'
log='condor.log'
