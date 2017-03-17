## See etc/config/default.sh for documentation and full list of parameters

# import settings from spatio-temporal atlas construction
source "$(dirname "$BASH_SOURCE")/config-proposed.sh"

# regression settings resulting in uniform weights
means=(40)
sigma=1000
epsilon=0.1
kernel="$pardir/uniform"

# output settings
subdir="dhcp-v2.4/dHCP43_40_uniform"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../output/$subdir/dofs"
evldir="../output/$subdir/eval"
outdir="../output/$subdir/atlas"
tmpdir="../output/$subdir/temp"
log="$logdir/progress.log"
