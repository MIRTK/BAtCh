## See etc/config/default.sh for documentation and full list of parameters

# normalization
refid='serag-40'

# input
set_pardir_from_file_path "$BASH_SOURCE"
agelst="$pardir/ages.csv"
sublst="$pardir/subjects.lst"

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
means=({36..44})
sigma=0.50
epsilon=0.001
kernel="$pardir/weights_constant_sigma=$sigma"
krnpre="t"
krnext="tsv"

# output settings
subdir="dhcp/v2.4/275_subjects_36-44_weeks/sigma_${sigma}_const"
dagdir="dag/$subdir"
logdir="log/$subdir"
dofdir="../output/$subdir/dofs"
evldir="../output/$subdir/eval"
outdir="../output/$subdir/atlas"
tmpdir="../output/$subdir/temp"
log="$logdir/progress.log"
