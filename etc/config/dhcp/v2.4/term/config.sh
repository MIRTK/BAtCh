## See etc/config/default.sh for documentation and full list of parameters

# reference for global normalization
refid='serag-40'

# input settings
pardir="`dirname "$BASH_SOURCE"`"
pardir="`cd $pardir && pwd`"
pardir="${pardir/$topdir\//}"

agelst="$pardir/ages.lst"
sublst="$pardir/subjects.lst"

# workflow parameters
resolution=0.5
similarity='NCC'
bending=1e-3
jacobian=1e-5
refine=1
epsilon=0.054
sigma=1
kernel="$pardir/kernels"
