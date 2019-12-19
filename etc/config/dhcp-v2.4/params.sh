## Registration parameters used in 2017 with MIRTK version 1 (rev 039e4bf, built on Apr 18 2017)
## to construct neonatal brain atlas for 36 to 44 weeks from dHCP images as part of the PhD thesis
## of Andreas Schuh (http://hdl.handle.net/10044/1/58880, Chapter 6.2).
##
## ATTENTION: MIRTK version 2 may need different parameters to yield similar results!

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
jacobian=1e-5
symmetric=true
pairwise=true
useresdof=false
inclbg=false
interpolation="Linear"
[[ $inclbg == true ]] || interpolation="$interpolation with padding"
