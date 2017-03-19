## See etc/config/default.sh for documentation and full list of parameters

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/common.sh"

[ -n "$sigma" ] || sigma=0.5
sigma=$(printf '%.2f' $sigma)
kernel="$pardir/adaptive-sigma_$sigma"

subdir="dHCP275/adaptive-sigma_$sigma"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
