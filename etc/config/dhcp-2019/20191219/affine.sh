## See etc/config/default.sh for documentation and full list of parameters
##
## Construct affine spatio-temporal atlas; no deformable registrations.

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/common.sh"

# registration parameters
pairwise=false
refine=0
finalize=false

# output settings
subsubdir="affine"
dagdir="dag/$subdir/$subsubdir"
logdir="log/$subdir/$subsubdir"
log="$logdir/progress.log"

resdir="out/$subdir/$subsubdir"
dofdir="../$resdir/dofs"
evldir="../$resdir/eval"
outdir="../$resdir/atlas"
tmpdir="../$resdir/temp"
