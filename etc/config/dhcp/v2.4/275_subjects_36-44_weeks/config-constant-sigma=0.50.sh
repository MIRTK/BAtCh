## See etc/config/default.sh for documentation and full list of parameters

source "$(dirname "$BASH_SOURCE")/config.sh"

sigma=0.50
kernel="$pardir/weights_constant_sigma=$sigma"

subdir="dhcp/v2.4/275_subjects_36-44_weeks/sigma_${sigma}_const"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../output/$subdir/dofs"
evldir="../output/$subdir/eval"
outdir="../output/$subdir/atlas"
tmpdir="../output/$subdir/temp"
log="$logdir/progress.log"
