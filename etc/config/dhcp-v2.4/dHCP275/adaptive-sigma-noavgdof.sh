## See etc/config/default.sh for documentation and full list of parameters

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/common.sh"

pairwise=false
refine=10

sigma=0.50
kernel="$pardir/adaptive-sigma_$sigma"

subdir="dHCP275/adaptive-sigma_$sigma-noavgdof"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
