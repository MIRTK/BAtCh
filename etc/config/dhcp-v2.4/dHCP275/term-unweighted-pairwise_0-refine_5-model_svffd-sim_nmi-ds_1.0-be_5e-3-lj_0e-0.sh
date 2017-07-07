## See etc/config/default.sh for documentation and full list of parameters

# import settings from default configuration
set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/term-unweighted.sh"

# registration parameters
similarity='nmi'
levels=5
spacing=1.0
bending=5e-3
jacobian=0e-0
pairwise=false
refine=5

# output settings
name="$(basename "$BASH_SOURCE")"
subdir="${name%.sh}"
dagdir="dag/dHCP275/$subdir"
logdir="log/dHCP275/$subdir"
log="$logdir/progress.log"

resdir="dhcp-n275-t36_44/constructed-atlases/$subdir"
dofdir="../$resdir/dofs"
evldir="../$resdir/eval"
outdir="../$resdir/atlas"
tmpdir="../$resdir/temp"
