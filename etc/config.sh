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
topdir="$appdir"                   # top-level working directory
imgdir='../images'                 # directory of anatomical brain images relative to $topdir
imgpre=''                          # image file name prefix
imgsuf='.nii.gz'                   # image file name suffix
lbldir='../labels'                 # directory of segmentations relative to $topdir
                                   # - $lbldir/tissues/:    Tissue segmentations
                                   # - $lbldir/structures/: Structural segmentations
lblpre=''                          # label image file name prefix
lblsuf='.nii.gz'                   # label image file name suffix
segdir='../masks'                  # directory with binary segmentation masks
segpre=''                          # binary segmentation file name prefix
segsuf='.nii.gz'                   # binary segmentation file name suffix
tissues=9                          # no. of tissue classes
structures=87                      # no. of structures
bgvalue=0                          # background value of skull-stripped images

# reference for global normalization
refdir='etc'                       # directory of reference image relative to $topdir
refpre=''                          # reference image file name prefix
refsuf='.nii.gz'                   # reference image file name suffix
refid='serag-40'                   # ID of reference image (optional)
                                   #
                                   # Set reference ID to empty string to compute age-
                                   # specific affine subject-to-template transformations
                                   # from affine transformations between all image pairs.

# parameters
resolution=0.5                     # highest image resolution at final level in mm
similarity='NCC'                   # image (dis-)similarity measure: SSD, NMI, NCC
refine=1                           # no. of template refinement steps
threads=8                          # maximum no. of CPU cores to use
epsilon=0.054                      # kernel weight threshold
[ -n "$sigma" ] || sigma=1         # (default) standard deviation of Gaussian
kernel="etc/kernel_sigma=$sigma"   # directory containing temporal kernel files relative to $topdir

# output settings
bindir='bin'                       # directory of job executable files relative to $topdir
libdir='lib'                       # directory of shared libraries required by job executables relative to $topdir
dagdir='dag'                       # directory of DAG files for HTCondor DAGMan jobs relative to $topdir
logdir='log'                       # directory of log files written by HTCondor jobs relative to $topdir
dofdir='../dofs'                   # transformations computed during atlas construction relative to $topdir
evldir='../eval'                   # directory of evaluation output files relative to $topdir
outdir='../atlas'                  # atlas output directory relative to $topdir
update='false'                     # enable (true) or disable update of existing DAG files

# HTCondor settings
notify_user="${USER}@imperial.ac.uk"
notification='Error'
requirements='Arch == "X86_64" && OpSysShortName == "Ubuntu" && OpSysMajorVer == 14'
log='condor.log'
