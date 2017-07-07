## See etc/config/default.sh for documentation and full list of parameters
##
## This atlas construction is based on the original spatio-temporal neonatal
## atlas construction approach proposed by Serag et al., NeuroImage 2012

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/adaptive-sigma.sh"

# registration parameters
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
useresdof=false
refine=0

# output settings
subdir="adaptive-sigma_$sigma-ffd-noresdof"
dagdir="dag/dHCP275/$subdir"
logdir="log/dHCP275/$subdir"
log="$logdir/progress.log"

resdir="dhcp-n275-t36_44/constructed-atlases/$subdir"
dofdir="../$resdir/dofs"
evldir="../$resdir/eval"
outdir="../$resdir/atlas"
tmpdir="../$resdir/temp"
