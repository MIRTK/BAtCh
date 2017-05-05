## See etc/config/default.sh for documentation and full list of parameters
##
## This configuration corresponds to the new atlas construction approach
## proposed by Schuh et al. 2014-2017.

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/common.sh"

# regression
means=(40)
sigma=1.00
epsilon=0.054
kernel="$pardir/sigma_$sigma"

# output settings
subdir="dHCP43/sigma_$sigma"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
