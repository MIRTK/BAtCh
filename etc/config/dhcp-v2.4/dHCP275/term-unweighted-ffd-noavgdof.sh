## See etc/config/default.sh for documentation and full list of parameters

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/term-unweighted-ffd-useresdof.sh"

# registration
pairwise=false

# output settings
subdir="term-unweighted-ffd-noavgdof"
dagdir="dag/dHCP275/$subdir"
logdir="log/dHCP275/$subdir"
log="$logdir/progress.log"

resdir="dhcp-n275-t36_44/constructed-atlases/$subdir"
dofdir="../$resdir/dofs"
evldir="../$resdir/eval"
outdir="../$resdir/atlas"
tmpdir="../$resdir/temp"
