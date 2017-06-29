## See etc/config/default.sh for documentation and full list of parameters

# import settings from spatio-temporal atlas construction
set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/term-unweighted.sh"

# no iterative refinement
refine=0

# output settings
subdir="dHCP275/term-unweighted-norefine"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
