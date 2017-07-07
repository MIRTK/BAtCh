## See etc/config/default.sh for documentation and full list of parameters
##
## This atlas construction is based on the original spatio-temporal neonatal
## atlas construction approach proposed by Serag et al., NeuroImage 2012
##
## - For iterative refinement, consider term-unweighted-ffd-useresdof.sh config
## - This configuration file is used to construct a term atlas from the pairwise
##   transformations alone for comparison to other approaches.

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/term-unweighted-ffd-useresdof.sh"

# registration parameters
useresdof=false
refine=0

# output settings
subdir="term-unweighted-ffd-noresdof"
dagdir="dag/dHCP275/$subdir"
logdir="log/dHCP275/$subdir"
log="$logdir/progress.log"

resdir="dhcp-n275-t36_44/constructed-atlases/$subdir"
dofdir="../$resdir/dofs"
evldir="../$resdir/eval"
outdir="../$resdir/atlas"
tmpdir="../$resdir/temp"
