## See etc/config/default.sh for documentation and full list of parameters

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/adaptive-sigma.sh"

refine=0

subdir="dHCP275/adaptive-sigma_$sigma-norefine"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
