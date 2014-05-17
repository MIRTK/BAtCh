################################################################################
#
################################################################################

[ -z $__utils_sh ] || __utils_sh=0

# -----------------------------------------------------------------------------
# import modules
_moddir="$(dirname "$BASH_SOURCE")"
. "$_moddir/core.sh" || { echo "Failed to import core module!" 1>&2; exit 1; }
. "$_moddir/path.sh" || { echo "Failed to import path module!" 1>&2; exit 1; }

# ------------------------------------------------------------------------------
# read subject IDs from text file
read_sublst()
{
  local ids=($(cat "$2" | cut -d' ' -f1 | cut -d, -f1 | cut -d# -f1))
  local num=${#ids[@]}
  if [ $num -gt 0 ]; then
    info "Read IDs of $num subjects"
  else
    error "Failed to read subject IDs from file $2"
  fi
  local "$1" && upvar $1 ${ids[@]}
}

# ------------------------------------------------------------------------------
# copy executable and its dependencies
pack_executable()
{
  if [ ! -f "$bindir/$1" ]; then
    local path="$(which "$IRTK_DIR/bin/$1" 2> /dev/null)"
    [ -n "$path" ] || path="$(which   "$1" 2> /dev/null)"
    makedir "$bindir"
    cp -f "$path" "$bindir/" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      info  "  Copied executable $path"
    else
      error "  Failed to copy executable $path"
    fi
  fi
}

# ------------------------------------------------------------------------------
# write common configuration of HTCondor job description, i.e., universe,
# executable, environment, and requirements to new file
make_submit_script()
{
  local universe=vanilla
  local executable=
  while [ $# -gt 0 ]; do
    case "$1" in
      -universe)   optarg universe   $1 "$2"; shift; ;;
      -executable) optarg executable $1 "$2"; shift; ;;
      --) shift; break; ;;
      *)         break; ;;
    esac
    shift
  done
  [ $# -eq 1         ] || error "Invalid number of arguments: $@"
  [ -n "$executable" ] || error "Missing -executable argument!"
  pack_executable "$executable"
  makedir "$(dirname "$1")"
  cat --<<EOF > "$1"
universe     = $universe
environment  = LD_LIBRARY_PATH=$libdir:$LIBRARY_PATH
initialdir   = $topdir
executable   = $bindir/$executable
log          = $log
notify_user  = $notify_user
notification = $notification
requirements = $requirements
EOF
}

# ------------------------------------------------------------------------------
# write PRE script of HTCondor DAGMan node
make_pre_script()
{
  makedir "$(dirname "$1")"
  cat --<<EOF > "$1"
#! /bin/bash
cd "$topdir" || exit 1
EOF
  chmod +x "$1" || exit 1
}

# ------------------------------------------------------------------------------
# append DAGMan node scripts
append_htcondor_node()
{
  [ $# -eq 1  ] || error "Invalid number of arguments!"
  [ -z "$pre" ] || append "$moddir/$1.pre.sh"     "$pre\n"
  [ -z "$sub" ] || append "$moddir/$1.condor.sub" "$sub\n"
  pre=''
  sub=''
}

# ------------------------------------------------------------------------------
# write DAGMan node scripts
make_htcondor_node()
{
  [ $# -eq 2 ] || error "Invalid number of arguments!"
  make_pre_script                        "$moddir/$1.pre.sh"
  make_submit_script -executable "$2" -- "$moddir/$1.condor.sub"
  append_htcondor_node "$1"
}

# ------------------------------------------------------------------------------
# write DAGMan node files for pairwise image registration using ireg
make_ireg_node()
{
  local node=
  local ids=
  local model=
  local energy='SIM[Similarity](I1, I2 o T)'
  local similarity='NMI'
  local hdrdofs=
  local dofins=
  local dofdir=
  local logdir=
  local params=''
  local padding=-32767

  while [ $# -gt 0 ]; do
    case "$1" in
      -name)               optarg  node       $1 "$2"; shift; ;;
      -subjects)           optargs ids "$@"; shift ${#ids[@]}; ;;
      -model)              optarg  model      $1 "$2"; shift; ;;
      -hdrdofs)            optarg  hdrdofs    $1 "$2"; shift; ;;
      -dofins)             optarg  dofins     $1 "$2"; shift; ;;
      -dofdir)             optarg  dofdir     $1 "$2"; shift; ;;
      -logdir)             optarg  logdir     $1 "$2"; shift; ;;
      -par)                optarg  param      $1 "$2"; shift; params="$params\n$param"; ;;
      -similarity)         optarg  similarity $1 "$2"; shift; ;;
      -bgvalue|-padding)   optarg  padding    $1 "$2"; shift; ;;
      -inverse-consistent) energy='0.5 SIM[Forward similarity](I1, I2 o T) + 0.5 SIM[Backward similarity](I1 o T^-1, I2)'; ;;
      -symmetric)          energy='SIM[Similarity](I1 o T^-0.5, I2 o T^0.5)'; ;;
      *) error "Unknown argument: $1"; ;;
    esac
    shift
  done
  [ -n "$node"       ] || error "Missing -name argument!"
  [ -n "$model"      ] || error "Missing -model argument!"
  [ ${#ids[@]} -ge 2 ] || error "Not enough -subjects specified!"

  local par="Transformation model             = $model"
  par="$par\nEnergy function                  = $energy"
  par="$par\nSimilarity measure               = $similarity"
  par="$par\nPadding value                    = $padding"
  par="$par\nMaximum streak of rejected steps = 3"
  par="$par\nStrict step length range         = No"
  par="$par\n$params"
  write "$pardir/$node.par" "$par\n"

  info "Adding ireg node $node..."
  local pre=''
  local sub=''
  local n=0
  make_htcondor_node "$node" ireg
  for id1 in "${ids[@]}"; do
    let n++
    [ -z "$dofdir" ] || pre="$pre\nmkdir -p '$dofdir/$id1' || exit 1"
    [ -z "$logdir" ] || pre="$pre\nmkdir -p '$logdir/$id1' || exit 1"
    for id2 in "${ids[@]}"; do
      [[ $id1 != $id2 ]] || continue
      sub="$sub\n\n# target: $id1, source: $id2"
      sub="$sub\narguments = \""
      if [ -n "$hdrdofs" ]; then
        sub="$sub -image '$imgdir/$id1.nii.gz' -dof '$hdrdofs/$id1.dof.gz'"
        sub="$sub -image '$imgdir/$id2.nii.gz' -dof '$hdrdofs/$id2.dof.gz'"
      else
        sub="$sub -image '$imgdir/$id1.nii.gz' -image '$imgdir/$id2.nii.gz'"
      fi
      sub="$sub -v"
      [ -z "$dofins" ] || sub="$sub -dofin '$dofins/$id1/$id2.dof.gz'"
      [ -z "$dofdir" ] || sub="$sub -dofout '$dofdir/$id1/$id2.dof.gz'"
      [ -z "$par"    ] || sub="$sub -parin '$pardir/$node.par'"
      [ -z "$logdir" ] || sub="$sub -parout '$logdir/$id1/$id2.par'"
      sub="$sub\""
      if [ -n "$logdir" ]; then
        sub="$sub\noutput    = $logdir/$id1/$id2.log"
        sub="$sub\nerror     = $logdir/$id1/$id2.log"
      fi
      sub="$sub\nqueue"
    done
    append_htcondor_node "$node"
    info "  `printf '%3d of %d: target=%s' $n ${#ids[@]} $id1`"
  done
  info "Adding ireg node $node... done"
}

# ------------------------------------------------------------------------------
# write DAGMan node files for averaging of transformations using dofaverage
make_dofaverage_node()
{
  local node=
  local ids=()
  local idlst=
  local dofins=
  local dofdir=
  local logdir=
  local options=''

  while [ $# -gt 0 ]; do
    case "$1" in
      -name)     optarg  node   $1 "$2"; shift; ;;
      -subjects) optargs ids "$@"; shift ${#ids[@]}; ;;
      -sublst)   optarg  sublst $1 "$2"; shift; ;;
      -dofins)   optarg  dofins $1 "$2"; shift; ;;
      -dofdir)   optarg  dofdir $1 "$2"; shift; ;;
      -logdir)   optarg  logdir $1 "$2"; shift; ;;
      -norigid)  options="$options -norigid";  ;;
      -dofs)     options="$options -dofs"; ;;
      *) error "Unknown argument: $1"; ;;
    esac
    shift
  done
  [ -n "$node"       ] || error "Missing -name argument!"
  [ -n "$dofins"     ] || error "Missing -dofins argument!"

  if [ -n "$idlst" ]; then
    [ ${#ids[@]} -eq 0 ] || error "Options -subjects and -sublst are mutual exclusive!"
    read_sublst ids "$idlst"
  else
    idlst="$pardir/$node.lst"
    local dofnames=
    for id in "${ids[@]}"; do
      dofnames="$dofnames$id\n"
    done
    write "$idlst" "$dofnames"
  fi

  info "Adding dofaverage node $node..."
  local pre=''
  local sub=''
  for id in "${ids[@]}"; do
    [ -z "$dofdir" ] || pre="$pre\nmkdir -p '$dofdir' || exit 1"
    [ -z "$logdir" ] || pre="$pre\nmkdir -p '$logdir' || exit 1"
    sub="$sub\n\n# subject: $id"
    sub="$sub\narguments = \"'$dofdir/$id.dof.gz' -all$options -add-identity-for-dofname '$id'"
    sub="$sub -dofdir '$dofins' -dofnames '$idlst' -prefix '$id/' -suffix .dof.gz"
    sub="$sub\""
    [ -z "$logdir" ] || sub="$sub\noutput    = $logdir/$id.log"
    sub="$sub\nqueue"
  done
  make_htcondor_node "$node" dofaverage
  info "Adding dofaverage node $node... done"
}

# ------------------------------------------------------------------------------
# write DAGMan node files for composition of transformations using dofcombine
make_dofcombine_node()
{
  local node=
  local ids=()
  local dofdir1=
  local dofdir2=
  local dofdir3=
  local logdir=
  local options=

  while [ $# -gt 0 ]; do
    case "$1" in
      -name)     optarg  node    $1 "$2"; shift; ;;
      -subjects) optargs ids "$@"; shift ${#ids[@]}; ;;
      -dofdir1)  optarg  dofdir1 $1 "$2"; shift; ;;
      -dofdir2)  optarg  dofdir2 $1 "$2"; shift; ;;
      -dofdir3)  optarg  dofdir3 $1 "$2"; shift; ;;
      -logdir)   optarg  logdir  $1 "$2"; shift; ;;
      -invert1)  options="$options -invert1";  ;;
      -invert2)  options="$options -invert2"; ;;
      *) error "Unknown argument: $1"; ;;
    esac
    shift
  done
  [ -n "$node"    ] || error "Missing -name argument!"
  [ -n "$dofdir1" ] || error "Missing -dofdir1 argument!"
  [ -n "$dofdir2" ] || error "Missing -dofdir2 argument!"
  [ -n "$dofdir3" ] || error "Missing -dofdir3 argument!"

  info "Adding dofcombine node $node..."
  local pre=''
  local sub=''
  for id in "${ids[@]}"; do
    pre="$pre\nmkdir -p '$dofdir3' || exit 1"
    sub="$sub\n\n# subject: $id"
    sub="$sub\narguments = \"'$dofdir1/$id.dof.gz' '$dofdir2/$id.dof.gz' '$dofdir3/$id.dof.gz'$options\""
    [ -z "$logdir" ] || pre="$pre\nmkdir -p '$logdir' || exit 1"
    [ -z "$logdir" ] || sub="$sub\noutput    = $logdir/$id.log"
    sub="$sub\nqueue"
  done
  make_htcondor_node "$node" dofcombine
  info "Adding dofcombine node $node... done"
}
