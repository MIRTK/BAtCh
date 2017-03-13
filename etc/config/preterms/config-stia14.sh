## Parameters used for MICCAI 2014 STIA Workshop
##
## Registration was based on former "ireg" binary of extended IRTK
## before additional extensive refactoring resulting in the MIRTK.
## Results with the new MIRTK will likely differ (generally better).
##
## See etc/config/default.sh for documentation and full list of parameters

# normalization
refid='serag-40'
refini=true

# input
set_pardir_from_file_path "$BASH_SOURCE"
agelst="$pardir/ages.csv"
sublst="$pardir/subjects.lst"

# registration
mffd='None'
model='SVFFD'
levels=4
resolution=1
interpolation='Linear'
similarity='NMI'
bins=64
inclbg=false
bending=1e-3
jacobian=1e-2
symmetric=true
pairwise=true
refine=0

# regression
means=({28..44})
sigma=1
epsilon=0.001
kernel="$pardir/weights"

# averaging options
normalization='none'
rescaling='none'
sharpen=false

# output settings
subdir="miccai14-stia"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../output/$subdir/dofs"
evldir="../output/$subdir/eval"
outdir="../output/$subdir/atlas"
tmpdir="../output/$subdir/temp"
log="$logdir/progress.log"
