## See etc/config/default.sh for documentation and full list of parameters

# normalization
refid='serag-40'

# input
set_pardir_from_file_path "$BASH_SOURCE"
agelst="$pardir/ages.csv"
#sublst="$pardir/subjects.lst"
sublst="$pardir/test.lst" # TODO: Remove this line

# registration
resolution=0.5
similarity='NMI'
bending=5e-3
jacobian=1e-4
refine=10

# regression
means=(40)
sigma=1
epsilon=0.054
kernel="$pardir/weights-test"

# output settings
dagdir="dag/test"
logdir="log/test"
dofdir="../output/test/dofs"
evldir="../output/test/eval"
outdir="../output/test/atlas"
tmpdir="../output/test/temp"
log="$dagdir/progress.log"
