## See etc/config/default.sh for documentation and full list of parameters
##
## This atlas construction is based on the original spatio-temporal neonatal
## atlas construction approach proposed by Serag et al., NeuroImage 2012

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/adaptive-sigma-ffd-noresdof.sh"

# registration parameters
useresdof=true

# output settings
subdir="adaptive-sigma_$sigma-ffd-useresdof"
dagdir="dag/dHCP275/$subdir"
logdir="log/dHCP275/$subdir"
log="$logdir/progress.log"

resdir="dhcp-n275-t36_44/constructed-atlases/$subdir"
dofdir="../$resdir/dofs"
evldir="../$resdir/eval"
outdir="../$resdir/atlas"
tmpdir="../$resdir/temp"
