## Parameters used for MICCAI 2014 STIA Workshop
##
## Registration was based on former "ireg" binary of extended IRTK
## before additional extensive refactoring resulting in the MIRTK.
## Results with the new MIRTK will likely differ (generally better).
##
## See etc/config/default.sh for documentation and full list of parameters

set_pardir_from_file_path "$BASH_SOURCE"

# input
agelst="$pardir/ages.csv"
sublst="$pardir/subjects.lst"

# normalization
refid="serag-40"
refini=true

# registration
mffd="None"
model="SVFFD"
levels=4
resolution=1
interpolation="Linear"
similarity="NMI"
bins=64
inclbg=false
bending=1e-3
jacobian=1e-2
symmetric=true
pairwise=true
refine=0

# regression
means=({28..44})
sigma=1.00
epsilon=0.001
kernel="$pardir/constant-sigma_$sigma"

# averaging options
normalization="none"
rescaling="none"
sharpen=false

# output settings
subdir="miccai14-stia"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
