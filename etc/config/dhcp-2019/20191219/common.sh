## See etc/config/default.sh for documentation and full list of parameters

set_pardir_from_file_path "$BASH_SOURCE"

# input
agelst="$pardir/ages.csv"
sublst="$pardir/subjects.lst"

input_dir="/vol/dhcp-derived-data/volumetric-atlases/workspace/input"

t1wdir="$input_dir/images/t1w"
t1wpre=""
t1wsuf=".nii.gz"

t2wdir="$input_dir/images/t2w"
t2wpre=""
t2wsuf=".nii.gz"

imgdir="$t2wdir"
imgpre="$t2wpre"
imgsuf="$t2wsuf"

bgvalue=0

lbldir="$input_dir/labels/structures"
lblpre=""
lblsuf=".nii.gz"

clsdir="$input_dir/labels/tissues"
clspre=""
clssuf=".nii.gz"

tissues=9
structures=87

segdir="$input_dir/masks"
segpre=""
segsuf=".nii.gz"

# spatial normalization
refdir="etc/reference"
refpre=""
refsuf=".nii.gz"
refid="schuh-t40"
refini=false

# regression
means=({29..44})
sigma=1.0
sigma=$(printf '%.2f' $sigma)
epsilon=0.001
kernel="$pardir/weights"
krnpre="t"
krnext="tsv"

# output settings
dagdir="dag"
logdir="log"
dofdir="out/dofs"
evldir="out/eval"
outdir="out/atlas"
tmpdir="out/temp"
log="$logdir/progress.log"
