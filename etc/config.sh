# IRTK installation
IRTK_DIR='/vol/biomedic/users/as12312/local/linux-3.6/irtk-nnatlas'
LIBRARY_PATH='/vol/biomedic/users/as12312/local/lib'

# input settings
topdir="$PWD"
imgdir='data/images'
lbldir='data/labels'
bgvalue=0

# output settings
bindir='bin'
libdir='lib'
pardir='etc'
dofdir='data/dofs'
logdir='log'
outdir='atlas'
tmpdir='tmp'

# HTCondor settings
notify_user='as12312@imperial.ac.uk'
notification='Error'
requirements='Arch == "X86_64" && OpSysShortName == "Ubuntu" && (OpSysMajorVer == 12 || OpSysMajorVer == 13)'
log="$logdir/htcondor.log"
