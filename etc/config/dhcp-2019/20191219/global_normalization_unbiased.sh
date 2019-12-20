## See etc/config/default.sh for documentation and full list of parameters
##
## Perform unbiased global normalization as described in Schuh (2017)
## chapter 6.1 using pairwise affine registrations with subsequent rigid
## alignment with reference image. This requires substantially more affine
## registrations than the "biased" global normalization which directly
## registers all images to the reference image.

set_pardir_from_file_path "$BASH_SOURCE"
source "$topdir/$pardir/global_normalization.sh"

# spatial normalization
refini=true

# registration parameters
pairwise=false
refine=0
finalize=false

# output settings
subdir="global_normalization_unbiased"
dagdir="dag/$subdir"
logdir="log/$subdir"
log="$logdir/progress.log"

resdir="out/$subdir"
dofdir="$resdir/dofs"
evldir="$resdir/eval"
outdir="$resdir/atlas"
tmpdir="$resdir/temp"
