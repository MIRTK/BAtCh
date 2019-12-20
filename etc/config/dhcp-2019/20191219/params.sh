## Registration parameters used in 2019 with MIRTK version 2 (rev 4b77b34, built on Dec 17 2019)
## to construct neonatal brain atlas for 29 to 44 weeks from dHCP images.

resolution=0.5
similarity="NMI"
radius=3
bins=64
model="SVFFD"
mffd="None"
levels=4
spacing=2.0
bending=5e-3
elasticity=0
elasticity_lambda=1.5
elasticity_mu=1
jacobian=1e-5
symmetric=true
pairwise=true
useresdof=false
inclbg=false
interpolation="Linear"
[[ $inclbg == true ]] || interpolation="$interpolation with padding"
