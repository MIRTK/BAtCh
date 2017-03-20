## See etc/config/default.sh for documentation and full list of parameters
##
## Configuration file for gen-normalization-tests workflow.

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/common.sh"

# registration
levels=4
resolution=0.5
interpolation='Linear with padding'
inclbg=false
similarity='NMI'
bins=64
refine=9

# output settings
subdir="normalization"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
