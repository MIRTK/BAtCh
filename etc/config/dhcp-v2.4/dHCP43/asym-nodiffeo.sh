## See etc/config/default.sh for documentation and full list of parameters
##
## This atlas construction is based on the original spatio-temporal neonatal
## atlas construction approach proposed by Serag et al., NeuroImage 2012

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/common.sh"

# registration
mffd='Sum'
model='Affine+FFD'
levels=4
resolution=0.5
interpolation='Linear with padding'
similarity='NMI'
bins=64
inclbg=false
spacing=2.0
bending=1e-3
jacobian=0
symmetric=false
pairwise=true
refine=0

# regression
means=(40)
sigma=1.00
epsilon=0.054
kernel="$pardir/sigma_$sigma"

# output settings
subdir="dHCP43/sigma_$sigma-asym-nodiffeo"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
