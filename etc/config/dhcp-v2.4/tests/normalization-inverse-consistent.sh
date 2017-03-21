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
symmetric=true
similarity='NMI'
bins=64
refine=9

# output settings
subdir="normalization-inverse-consistent"
dagdir="dag/tests/$subdir"
logdir="log/tests/$subdir"
dofdir="../tests/$subdir/dofs"
evldir="../tests/$subdir/eval"
outdir="../tests/$subdir/atlas"
tmpdir="../tests/$subdir/temp"
log="$logdir/progress.log"
