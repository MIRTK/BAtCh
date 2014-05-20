################################################################################
#
################################################################################

[ -z $__daggen_irtk_sh ] || __daggen_irtk_sh=0

# ------------------------------------------------------------------------------
# import modules
_moddir="$(dirname "$BASH_SOURCE")"
. "$_moddir/dag.sh" || { echo "Failed to import daggen/dag module!" 1>&2; exit 1; }

# ------------------------------------------------------------------------------
# read subject IDs from text file (first column)
read_sublst()
{
  local ids=($(cat "$2" | cut -d' ' -f1 | cut -d, -f1 | cut -d# -f1))
  [ ${#ids[@]} -gt 0 ] || error "Failed to read subject IDs from file $2"
  local "$1" && upvar $1 ${ids[@]}
}

# ------------------------------------------------------------------------------
# add node for pairwise image registration
ireg_node()
{
  local node=
  local parent=()
  local ids=
  local model=
  local fidelity='SIM[Similarity](I1, I2 o T)'
  local similarity='NMI'
  local hdrdofs=
  local dofins=
  local dofdir=
  local params=
  local padding=-32767
  local ic='false'

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
      -inverse-consistent) ic='true'; fidelity='0.5 SIM[Forward similarity](I1, I2 o T) + 0.5 SIM[Backward similarity](I1 o T^-1, I2)'; ;;
      -symmetric)          ic='true'; fidelity='SIM[Similarity](I1 o T^-0.5, I2 o T^0.5)'; ;;
      -*)                  error "ireg_node: invalid option: $1"; ;;
      *)                   [ -z "$node" ] || error "ireg_node: too many arguments"
                           node=$1; ;;
    esac
    shift
  done
  [ -n "$node"       ] || error "ireg_node: missing name argument"
  [ -n "$model"      ] || error "ireg_node: missing -model argument"
  [ ${#ids[@]} -ge 2 ] || error "ireg_node: not enough -subjects specified"

  # number of pairwise registrations
  local N
  let N="${#ids[@]} * (${#ids[@]} - 1)"
  [[ $ic == false ]] || let N="$N / 2"


  # add SUBDAG node
  info "Adding node $node..."
  begin_dag $node -splice || {

    # registration parameters
    local par="Transformation model             = $model"
    par="$par\nEnergy function                  = $fidelity + 0 BE[Bending energy] + 0 JAC[Jacobian penalty]"
    par="$par\nSimilarity measure               = $similarity"
    par="$par\nPadding value                    = $padding"
    par="$par\nMaximum streak of rejected steps = 3"
    par="$par\nStrict step length range         = No"
    par="$par\n$params"
    parin="$_dagdir/ireg.par"
    write "$parin" "$par\n"

    # create generic ireg submission script
    local sub="arguments    = \""
    if [ -n "$hdrdofs" ]; then
      sub="$sub -image '$imgdir/\$(target).nii.gz' -dof '$hdrdofs/\$(target).dof.gz'"
      sub="$sub -image '$imgdir/\$(source).nii.gz' -dof '$hdrdofs/\$(source).dof.gz'"
    else
      sub="$sub -image '$imgdir/\$(target).nii.gz' -image '$imgdir/\$(source).nii.gz'"
    fi
    sub="$sub -v"
    [ -z "$dofins" ] || sub="$sub -dofin  '$dofins/\$(target)/\$(source).dof.gz'"
    [ -z "$dofdir" ] || sub="$sub -dofout '$dofdir/\$(target)/\$(source).dof.gz'"
    sub="$sub -parin '$parin' -parout '$_dagdir/\$(target)/ireg_\$(target),\$(source).par'"
    sub="$sub\""
    sub="$sub\noutput       = $_dagdir/\$(target)/register_\$(target),\$(source).out"
    sub="$sub\nerror        = $_dagdir/\$(target)/register_\$(target),\$(source).out"
    sub="$sub\nqueue"
    make_sub_script "register.sub" "$sub" -executable ireg

    # create generic dofinvert submission script
    if [[ $ic == true ]]; then
      # command used to invert inverse-consistent transformation
      local invcmd='ffdinvert'
      if [[ $model == Rigid ]] || [[ $model == Similarity ]] || [[ $model == Affine ]]; then
        invcmd='dofinvert'
      fi
      local sub="arguments    = \"'$dofdir/\$(target)/\$(source).dof.gz' '$dofdir/\$(source)/\$(target).dof.gz'\""
      sub="$sub\noutput       = $_dagdir/\$(target)/invert_\$(target),\$(source).out"
      sub="$sub\nerror        = $_dagdir/\$(target)/invert_\$(target),\$(source).out"
      sub="$sub\nqueue"
      make_sub_script "invert.sub" "$sub" -executable $invcmd
    fi

    # job to create output directories
    # better to have it done by a single script for all directories
    # than a PRE script for each registration job, which would require
    # the -maxpre option to avoid memory issues
    local pre=
    for id in "${ids[@]}"; do
      # directory for log files
      pre="$pre\nmkdir -p '$_dagdir/$id' || exit 1"
    done
    if [ -n "$dofdir" ]; then
      pre="$pre\n"
      for id in "${ids[@]}"; do
        # directory for output files
        pre="$pre\nmkdir -p '$dofdir/$id' || exit 1"
      done
    fi
    make_script "mkdirs.sh" "$pre"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.out\nqueue"

    # add job nodes
    local n t s prefile pre post
    n=0
    t=0
    for id1 in "${ids[@]}"; do
      let t++
      # register image id1 to all other images
      s=0
      for id2 in "${ids[@]}"; do
        let s++
        if [[ $ic == true ]]; then
          [ $t -lt $s ] || continue
        else
          [ $t -ne $s ] || continue
        fi
        let n++
        # node to register id1 and id2
        add_node "reg_$id1,$id2" -subfile "registration.sub"   \
                                 -var     "target=$id1"        \
                                 -var     "source=$id2"
        add_edge "reg_$id1,$id2" 'mkdirs'
        # node to invert inverse-consistent transformation
        if [[ $ic == true ]] && [ -n "$dofdir" ]; then
          add_node "invert_$id1,$id2" -subfile "invert.sub"    \
                                      -var     "target=$id1"   \
                                      -var     "source=$id2"
          add_edge "invert_$id1,$id2" "reg_$id1,$id2"
        fi
        info "  Added job `printf '%3d of %d' $n $N`"
      done
    done
  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
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
      *)         [ -z "$node" ] || error "dofaverage_node: too many arguments"
                 node=$1; ;;
    esac
    shift
  done
  [ -n "$node"   ] || error "dofaverage_node: missing name argument"
  [ -n "$dofins" ] || error "dofaverage_node: missing -dofins argument"

  if [ -z "$doflst" ]; then
    [ ${#ids[@]} -gt 0 ] || error "dofaverage_node: missing -subjects or -doflst argument"
    local dofnames=
    for id in "${ids[@]}"; do
      dofnames="$dofnames$id\t1\n"
    done
    doflst="$_dagdir/$node.par"
    write "$doflst" "$dofnames"
  elif [ ${#ids[@]} -eq 0 ]; then
    read_sublst ids "$doflst"
  fi

  info "Adding node $node..."
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
    sub="$sub\nerror     = $_dagdir/$node.log/dofaverage_$id.out"
    sub="$sub\nqueue"
  done
  add_node $node -executable dofaverage -pre "$pre" -sub "$sub"
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
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

  info "Adding node $node..."
  local pre=''
  local sub=''
  pre="$pre\nmkdir -p '$_dagdir/$node.log' || exit 1"
  pre="$pre\nmkdir -p '$dofdir3' || exit 1"
  for id in "${ids[@]}"; do
    sub="$sub\n\n# subject: $id"
    sub="$sub\narguments = \"'$dofdir1/$id.dof.gz' '$dofdir2/$id.dof.gz' '$dofdir3/$id.dof.gz'$options\""
    sub="$sub\noutput    = $_dagdir/$node.log/dofcombine_$id.out"
    sub="$sub\nerror     = $_dagdir/$node.log/dofcombine_$id.out"
    sub="$sub\nqueue"
  done
  add_node $node -executable dofcombine -pre "$pre" -sub "$sub"
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}
