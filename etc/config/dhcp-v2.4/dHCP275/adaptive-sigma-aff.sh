## See etc/config/default.sh for documentation and full list of parameters
##
## Construct affine spatio-temporal atlas; no deformable registrations.

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/common.sh"

# registration parameters
pairwise=false
refine=0

# regression parameters
[ -n "$sigma" ] || sigma=1.0
sigma=$(printf '%.2f' $sigma)
kernel="$pardir/adaptive-sigma_$sigma"

# output settings
subdir="adaptive-sigma_$sigma-aff"
dagdir="dag/dHCP275/$subdir"
logdir="log/dHCP275/$subdir"
log="$logdir/progress.log"

resdir="dhcp-n275-t36_44/constructed-atlases/$subdir"
dofdir="../$resdir/dofs"
evldir="../$resdir/eval"
outdir="../$resdir/atlas"
tmpdir="../$resdir/temp"
