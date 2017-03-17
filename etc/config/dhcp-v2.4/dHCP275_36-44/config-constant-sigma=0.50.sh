## See etc/config/default.sh for documentation and full list of parameters

source "$(dirname "$BASH_SOURCE")/config-common.sh"

sigma=0.50
kernel="$pardir/weights_constant_sigma=$sigma"

subdir="dHCP275_36-44_sigma_${sigma}_const"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
