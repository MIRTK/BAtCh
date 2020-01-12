## See etc/config/default.sh for documentation and full list of parameters

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/common.sh"

# regression
kernel="$pardir/constant_sigma_$sigma"

# output settings
subdir="constant_sigma_${sigma}"
dagdir="dag/$subdir"
logdir="log/$subdir"
log="$logdir/progress.log"

resdir="out/$subdir"
dofdir="$resdir/dofs"
evldir="$resdir/eval"
outdir="$resdir/atlas"
tmpdir="$resdir/temp"
