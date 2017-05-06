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

# registration
useresdof=false
refine=0

# output settings
subdir="dHCP275/term-unweighted-ffd-noresdof"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
