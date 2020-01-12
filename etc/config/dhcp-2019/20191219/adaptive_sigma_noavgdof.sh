## See etc/config/default.sh for documentation and full list of parameters

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/adaptive_sigma.sh"

# registration parameters
pairwise=false

# output settings
subdir="${subdir}_noavgdof"
dagdir="dag/$subdir"
logdir="log/$subdir"
log="$logdir/progress.log"

resdir="out/$subdir"
dofdir="$resdir/dofs"
evldir="$resdir/eval"
outdir="$resdir/atlas"
tmpdir="$resdir/temp"
