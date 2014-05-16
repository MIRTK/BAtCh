# IRTK installation
RUNTIME_PATH='/vol/biomedic/users/as12312/local/linux-3.6/irtk-nnatlas/bin'
LIBRARY_PATH='/vol/biomedic/users/as12312/local/lib'

# HTCondor settings
notify_user='as12312@imperial.ac.uk'
notification='Error'
requirements='Arch == "X86_64" && OpSysShortName == "Ubuntu" && (OpSysMajorVer == 12 || OpSysMajorVer == 13)'
log='logs/htcondor.log'

# input settings
topdir="$PWD"
imgdir='images'
lbldir='labels'
bgvalue=0

# output settings
bindir='bin'
libdir='lib'
pardir='etc'
dofdir='dofs'
logdir='logs'
outdir='atlas'
tmpdir='tmp'
