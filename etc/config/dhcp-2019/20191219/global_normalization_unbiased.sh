## See etc/config/default.sh for documentation and full list of parameters
##
## Perform unbiased global normalization.

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/global_normalization_biased.sh"

# spatial normalization
refini=true

# registration parameters
pairwise=false
refine=0
finalize=false

# output settings
subdir="global_normalization_unbiased"
dagdir="dag/$subdir"
logdir="log/$subdir"
log="$logdir/progress.log"

resdir="out/$subdir"
dofdir="$resdir/dofs"
evldir="$resdir/eval"
outdir="$resdir/atlas"
tmpdir="$resdir/temp"
