################################################################################
#
################################################################################

[ -z $__daggen_irtk_sh ] || __daggen_irtk_sh=0

# ------------------------------------------------------------------------------
# import modules
_moddir="$(dirname "$BASH_SOURCE")"
. "$_moddir/dag.sh" || { echo "Failed to import daggen/dag module!" 1>&2; exit 1; }

# ------------------------------------------------------------------------------
# add node for pairwise image registration
ireg_node()
{
  local node=
  local parent=()
  local ids=
  local model=
  local energy='SIM[Similarity](I1, I2 o T)'
  local similarity='NMI'
  local hdrdofs=
  local dofins=
  local dofdir=
  local params=''
  local padding=-32767

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)             optargs parent    "$@"; shift ${#parent[@]}; ;;
      -subjects)           optargs ids       "$@"; shift ${#ids[@]}; ;;
      -model)              optarg  model      $1 "$2"; shift; ;;
      -hdrdofs)            optarg  hdrdofs    $1 "$2"; shift; ;;
      -dofins)             optarg  dofins     $1 "$2"; shift; ;;
      -dofdir)             optarg  dofdir     $1 "$2"; shift; ;;
      -par)                optarg  param      $1 "$2"; shift; params="$params\n$param"; ;;
      -similarity)         optarg  similarity $1 "$2"; shift; ;;
      -bgvalue|-padding)   optarg  padding    $1 "$2"; shift; ;;
      -inverse-consistent) energy='0.5 SIM[Forward similarity](I1, I2 o T) + 0.5 SIM[Backward similarity](I1 o T^-1, I2)'; ;;
      -symmetric)          energy='SIM[Similarity](I1 o T^-0.5, I2 o T^0.5)'; ;;
      -*)                  error "ireg_node: invalid option: $1"; ;;
      *)                   [ -z "$node" ] || error "ireg_node: too many arguments"
                           node=$1; ;;
    esac
    shift
  done
  [ -n "$node"       ] || error "ireg_node: missing name argument"
  [ -n "$model"      ] || error "ireg_node: missing -model argument"
  [ ${#ids[@]} -ge 2 ] || error "ireg_node: not enough -subjects specified"

  local par="Transformation model             = $model"
  par="$par\nEnergy function                  = $energy"
  par="$par\nSimilarity measure               = $similarity"
  par="$par\nPadding value                    = $padding"
  par="$par\nMaximum streak of rejected steps = 3"
  par="$par\nStrict step length range         = No"
  par="$par\n$params"
  parin="$_dagdir/$node.par"
  write "$parin" "$par\n"

  info "Adding ireg node $node..."
  local pre=
  local sub=
  local n=0
  begin_dag $node
  for id1 in "${ids[@]}"; do
    let n++
    pre="$pre\nmkdir -p '$_dagdir/ireg_$id1.log' || exit 1"
    [ -z "$dofdir" ] || pre="$pre\nmkdir -p '$dofdir/$id1' || exit 1"
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
      [ -z "$dofins" ] || sub="$sub -dofin  '$dofins/$id1/$id2.dof.gz'"
      [ -z "$dofdir" ] || sub="$sub -dofout '$dofdir/$id1/$id2.dof.gz'"
      sub="$sub -parin '$parin' -parout '$_dagdir/ireg_$id1.log/ireg_$id1,$id2.par'"
      sub="$sub\""
      sub="$sub\noutput    = $_dagdir/ireg_$id1.log/ireg_$id1,$id2.out"
      sub="$sub\nerror     = $_dagdir/ireg_$id1.log/ireg_$id1,$id2.err"
      sub="$sub\nqueue"
    done
    add_node ireg_$id1 ireg
    info "  Added subnode `printf '%3d of %d' $n ${#ids[@]}`"
  done
  end_dag
  add_edge $node ${parent[@]}
  info "Adding ireg node $node... done"
}

# ------------------------------------------------------------------------------
# add node for averaging of transformations
dofaverage_node()
{
  local node=
  local parent=()
  local ids=()
  local doflst=
  local dofins=
  local dofdir=
  local options=''

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids    "$@"; shift ${#ids[@]}; ;;
      -doflst)   optarg  doflst $1 "$2"; shift; ;;
      -dofins)   optarg  dofins $1 "$2"; shift; ;;
      -dofdir)   optarg  dofdir $1 "$2"; shift; ;;
      -norigid)  options="$options -norigid";  ;;
      -dofs)     options="$options -dofs"; ;;
      -*)        error "dofaverage_node: invalid option: $1"; ;;
      *)         [ -z "$node" ] || error "Too many arguments"
                 node=$1; ;;
    esac
    shift
  done
  [ -n "$node"   ] || error "dofaverage_node: missing name argument"
  [ -n "$dofins" ] || error "dofaverage_node: missing -dofins argument"

  if [ -z "$doflst" ]; then
    local dofnames=
    for id in "${ids[@]}"; do
      dofnames="$dofnames$id\t1\n"
    done
    doflst="$_dagdir/$node.par"
    write "$doflst" "$dofnames"
  fi

  info "Adding dofaverage node $node..."
  local pre=''
  local sub=''
  pre="$pre\nmkdir -p '$_dagdir/$node.log' || exit 1"
  [ -z "$dofdir" ] || pre="$pre\nmkdir -p '$dofdir' || exit 1"
  for id in "${ids[@]}"; do
    sub="$sub\n\n# subject: $id"
    sub="$sub\narguments = \"'$dofdir/$id.dof.gz' -all$options -add-identity-for-dofname '$id'"
    sub="$sub -dofdir '$dofins' -dofnames '$doflst' -prefix '$id/' -suffix .dof.gz"
    sub="$sub\""
    sub="$sub\noutput    = $_dagdir/$node.log/dofaverage_$id.out"
    sub="$sub\nerror     = $_dagdir/$node.log/dofaverage_$id.err"
    sub="$sub\nqueue"
  done
  add_node $node dofaverage
  add_edge $node ${parent[@]}
  info "Adding dofaverage node $node... done"
}

# ------------------------------------------------------------------------------
# add node for composition of transformations
dofcombine_node()
{
  local node=
  local parent=()
  local ids=()
  local dofdir1=
  local dofdir2=
  local dofdir3=
  local options=

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids    "$@"; shift ${#ids[@]}; ;;
      -dofdir1)  optarg  dofdir1 $1 "$2"; shift; ;;
      -dofdir2)  optarg  dofdir2 $1 "$2"; shift; ;;
      -dofdir3)  optarg  dofdir3 $1 "$2"; shift; ;;
      -invert1)  options="$options -invert1";  ;;
      -invert2)  options="$options -invert2"; ;;
      -*)        error "dofcombine_node: invalid option: $1"; ;;
      *)         [ -z "$node" ] || error "dofcombine_node: too many arguments"
                 node=$1; ;;
    esac
    shift
  done
  [ -n "$node"    ] || error "dofcombine_node: missing name argument"
  [ -n "$dofdir1" ] || error "dofcombine_node: missing -dofdir1 argument"
  [ -n "$dofdir2" ] || error "dofcombine_node: missing -dofdir2 argument"
  [ -n "$dofdir3" ] || error "dofcombine_node: missing -dofdir3 argument"

  info "Adding dofcombine node $node..."
  local pre=''
  local sub=''
  pre="$pre\nmkdir -p '$_dagdir/$node.log' || exit 1"
  pre="$pre\nmkdir -p '$dofdir3' || exit 1"
  for id in "${ids[@]}"; do
    sub="$sub\n\n# subject: $id"
    sub="$sub\narguments = \"'$dofdir1/$id.dof.gz' '$dofdir2/$id.dof.gz' '$dofdir3/$id.dof.gz'$options\""
    sub="$sub\noutput    = $_dagdir/$node.log/dofcombine_$id.out"
    sub="$sub\nerror     = $_dagdir/$node.log/dofcombine_$id.err"
    sub="$sub\nqueue"
  done
  add_node $node dofcombine
  add_edge $node ${parent[@]}
  info "Adding dofcombine node $node... done"
}