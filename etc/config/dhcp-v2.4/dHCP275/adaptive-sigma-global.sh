## See etc/config/default.sh for documentation and full list of parameters
##
## Construct affine spatio-temporal atlas; no deformable registrations.

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/common.sh"

pairwise=false
refine=0

[ -n "$sigma" ] || sigma=1.0
sigma=$(printf '%.2f' $sigma)
kernel="$pardir/adaptive-sigma_$sigma"

subdir="dHCP275/adaptive-sigma_$sigma-global"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
