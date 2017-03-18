## See etc/config/default.sh for documentation and full list of parameters

# import settings from spatio-temporal atlas construction
set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/config.sh"

# regression settings resulting in uniform weights
means=(40)
sigma=1000
epsilon=0.1
kernel="$pardir/unweighted"

# output settings
subdir="dHCP43/unweighted"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
