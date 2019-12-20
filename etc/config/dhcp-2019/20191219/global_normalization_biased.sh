## See etc/config/default.sh for documentation and full list of parameters
##
## Perform global normalization by registering all T2w images to the 40 week
## template that was created previously from 275 term-born neonatal dHCP scans.

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/common.sh"

# spatial normalization
refdir="etc/reference"
refpre=""
refsuf=".nii.gz"
refid="schuh-t40"
refini=false

# registration parameters
pairwise=false
refine=0
finalize=false

# output settings
subdir="global_normalization_biased"
dagdir="dag/$subdir"
logdir="log/$subdir"
log="$logdir/progress.log"

resdir="out/$subdir"
dofdir="$resdir/dofs"
evldir="$resdir/eval"
outdir="$resdir/atlas"
tmpdir="$resdir/temp"
