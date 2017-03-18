## See etc/config/default.sh for documentation and full list of parameters
##
## This configuration corresponds to the new atlas construction approach
## proposed by Schuh et al. 2014-2017.

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/common.sh"

# registration
mffd='None'
model='SVFFD'
levels=4
resolution=0.5
interpolation='Linear with padding'
similarity='NMI'
bins=64
inclbg=false
bending=5e-3
jacobian=1e-4
symmetric=true
pairwise=true
refine=10

# regression
means=(40)
sigma=1.00
epsilon=0.054
kernel="$pardir/sigma_$sigma"

# output settings
subdir="dHCP43/sigma_$sigma"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
