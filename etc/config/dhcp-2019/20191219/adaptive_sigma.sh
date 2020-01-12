## See etc/config/default.sh for documentation and full list of parameters

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/common.sh"

# kernel regression
kernel="$pardir/adaptive_sigma_0.38-1.50"

# output settings
subdir="adaptive_sigma_0.38-1.50"
dagdir="dag/$subdir"
logdir="log/$subdir"
log="$logdir/progress.log"

resdir="out/$subdir"
dofdir="$resdir/dofs"
evldir="$resdir/eval"
outdir="$resdir/atlas"
tmpdir="$resdir/temp"
