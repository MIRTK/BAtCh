## See etc/config/default.sh for documentation and full list of parameters
##
## This atlas construction is based on the original spatio-temporal neonatal
## atlas construction approach proposed by Serag et al., NeuroImage 2012

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/adaptive-sigma-ffd-noresdof.sh"

# registration
useresdof=true

# output settings
subdir="dHCP275/adaptive-sigma_$sigma-ffd-useresdof"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
