## See etc/config/default.sh for documentation and full list of parameters

set_pardir_from_file_path "$BASH_SOURCE"

# input
agelst="$pardir/ages.csv"
sublst="$pardir/subjects.lst"

dhcp_structural_pipeline="/vol/dhcp-derived-data/structural-pipeline/dhcp-v2.4"

t1wdir="$dhcp_structural_pipeline/restore/T1"
t1wpre=""
t1wsuf="_restore_bet.nii.gz"

t2wdir="$dhcp_structural_pipeline/restore/T2"
t2wpre=""
t2wsuf="_restore_bet.nii.gz"

imgdir="$t2wdir"
imgpre="$t2wpre"
imgsuf="$t2wsuf"

bgvalue=0

lbldir="$dhcp_structural_pipeline/segmentations"
lblpre=""
lblsuf="_all_labels.nii.gz"
clspre=""
clssuf="_tissue_labels.nii.gz"
tissues=9
structures=87

segdir="seg"
segpre=""
segsuf=".nii.gz"

# spatial normalization
refdir="etc/reference"
refpre=""
refsuf=".nii.gz"
refid="serag-t40"
refini=true

# registration
mffd="None"
model="SVFFD"
levels=4
resolution=0.5
interpolation="Linear with padding"
similarity="NMI"
bins=64
inclbg=false
bending=5e-3
jacobian=1e-4
symmetric=true
pairwise=true
refine=10

# regression
means=({36..44})
[ -n "$sigma" ] || sigma=0.5
sigma=$(printf '%.2f' $sigma)
epsilon=0.001
kernel="$pardir/constant_sigma=$sigma"
krnpre="t"
krnext="tsv"

# output settings
subdir="dHCP275/constant_sigma_$sigma"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../$subdir/dofs"
evldir="../$subdir/eval"
outdir="../$subdir/atlas"
tmpdir="../$subdir/temp"
log="$logdir/progress.log"
