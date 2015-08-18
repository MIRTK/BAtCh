################################################################################
#
################################################################################

[ -z $__daggen_irtk_sh ] || return 0
__daggen_irtk_sh=0

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
  local refid=
  local refdir=
  local mask=
  local ids=
  local model=
  local mask=
  local fidelity='SIM[Similarity](I1, I2 o T)'
  local similarity='NMI'
  local hdrdofs=
  local hdrdof_opt='-dof'
  local dofins=
  local dofdir=
  local params=
  local padding=-32767
  local ic='false'

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)             optargs parent    "$@"; shift ${#parent[@]}; ;;
      -refid)              optarg  refid      $1 "$2"; shift; ;;
      -refdir)             optarg  refdir     $1 "$2"; shift; ;;
      -mask)               optarg  mask       $1 "$2"; shift; ;;
      -subjects)           optargs ids       "$@"; shift ${#ids[@]}; ;;
      -model)              optarg  model      $1 "$2"; shift; ;;
      -hdrdofs)            optarg  hdrdofs    $1 "$2"; shift; hdrdof_opt='-dof'; ;;
      -invhdrdofs)         optarg  hdrdofs    $1 "$2"; shift; hdrdof_opt='-dof_i'; ;;
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
  [ ${#ids[@]} -ge 2 ] || [ ${#ids[@]} -gt 0 -a -n "$refid" ] || error "ireg_node: not enough -subjects specified"

  # number of registrations
  local N
  if [ -n "$refid" ]; then
    N=${#ids[@]}
  else
    let N="${#ids[@]} * (${#ids[@]} - 1)"
    [[ $ic == false ]] || let N="$N / 2"
  fi

  # add SUBDAG node
  info "Adding node $node..."
  begin_dag $node -splice || {

    # registration parameters
    local cfg="Transformation model             = $model"
    cfg="$cfg\nEnergy function                  = $fidelity + 0 BE[Bending energy] + 0 JAC[Jacobian penalty]"
    cfg="$cfg\nSimilarity measure               = $similarity"
    cfg="$cfg\nPadding value                    = $padding"
    cfg="$cfg\nMaximum streak of rejected steps = 1"
    cfg="$cfg\nStrict step length range         = No"
    cfg="$cfg\n$params"
    parin="$_dagdir/ireg.cfg"
    write "$parin" "$cfg\n"

    # create generic ireg submission script
    local sub="arguments    = \"-v"
    if [ -n "$refid" -a -n "$refdir" ]; then
      if [ -n "$hdrdofs" ]; then
        sub="$sub -image '$refdir/$refpre\$(target)$refsuf' -image '$imgdir/$imgpre\$(source)$imgsuf'"
        sub="$sub $hdrdof_opt '$hdrdofs/\$(source).dof.gz'"
      else
        sub="$sub -image '$refdir/$refpre\$(target)$refsuf' -image '$imgdir/$imgpre\$(source)$imgsuf'"
      fi
    else
      if [ -n "$hdrdofs" ]; then
        sub="$sub -image '$imgdir/$imgpre\$(target)$imgsuf'"
        [ -n "$refid" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(target).dof.gz'"
        sub="$sub -image '$imgdir/$imgpre\$(source)$imgsuf' $hdrdof_opt '$hdrdofs/\$(source).dof.gz'"
      else
        sub="$sub -image '$imgdir/$imgpre\$(target)$imgsuf' -image '$imgdir/$imgpre\$(source)$imgsuf'"
      fi
    fi
    [ -z "$dofins" ] || {
      if [[ "$dofins" == "Id" ]]; then
        sub="$sub -dofin Id"
      else
        sub="$sub -dofin '$dofins/\$(target)/\$(source).dof.gz'"
      fi
    }
    [ -z "$dofdir" ] || sub="$sub -dofout '$dofdir/\$(target)/\$(source).dof.gz'"
    [ -z "$mask"   ] || sub="$sub -mask '$mask'"
    sub="$sub -parin '$parin' -parout '$_dagdir/\$(target)/ireg_\$(target),\$(source).par'"
    sub="$sub\""
    sub="$sub\noutput       = $_dagdir/\$(target)/imgreg_\$(target),\$(source).out"
    sub="$sub\nerror        = $_dagdir/\$(target)/imgreg_\$(target),\$(source).out"
    sub="$sub\nqueue"
    make_sub_script "imgreg.sub" "$sub" -executable ireg

    # create generic dofinvert submission script
    if [[ $ic == true ]] && [ -z "$refid" ] ; then
      # command used to invert inverse-consistent transformation
      local sub="arguments    = \"'$dofdir/\$(target)/\$(source).dof.gz' '$dofdir/\$(source)/\$(target).dof.gz'\""
      sub="$sub\noutput       = $_dagdir/\$(target)/dofinv_\$(target),\$(source).out"
      sub="$sub\nerror        = $_dagdir/\$(target)/dofinv_\$(target),\$(source).out"
      sub="$sub\nqueue"
      if [[ $model == Rigid ]] || [[ $model == Similarity ]] || [[ $model == Affine ]]; then
        make_sub_script "dofinv.sub" "$sub" -executable dofinvert
      else
        make_sub_script "dofinv.sub" "$sub" -executable ffdinvert
      fi
    fi

    # job to create output directories
    # better to have it done by a single script for all directories
    # than a PRE script for each registration job, which would require
    # the -maxpre option to avoid memory issues
    local pre=
    if [ -n "$refid" ]; then
      # directory for log files
      pre="$pre\nmkdir -p '$_dagdir/$refid' || exit 1"
      if [ -n "$dofdir" ]; then
        # directory for output files
        pre="$pre\nmkdir -p '$dofdir/$refid' || exit 1"
      fi
    else
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
    fi
    make_script "mkdirs.sh" "$pre"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.out\nqueue"

    # add job nodes
    local n t s prefile pre post
    if [ -n "$refid" ]; then
      n=0
      for id in "${ids[@]}"; do
        let n++
        # node to register image to common reference
        add_node "imgreg_$refid,$id" -subfile "imgreg.sub" \
                                     -var     "target=\"$refid\"" \
                                     -var     "source=\"$id\""
        add_edge "imgreg_$refid,$id" 'mkdirs'
        [ ! -f "$dofdir/$refid/$id.dof.gz" ] || node_done "imgreg_$refid,$id"
      done
    else
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
          add_node "imgreg_$id1,$id2" -subfile "imgreg.sub" \
                                      -var     "target=\"$id1\"" \
                                      -var     "source=\"$id2\""
          add_edge "imgreg_$id1,$id2" 'mkdirs'
          [ ! -f "$dofdir/$id1/$id2.dof.gz" ] || node_done "imgreg_$id1,$id2"
          # node to invert inverse-consistent transformation
          if [[ $ic == true ]] && [ -n "$dofdir" ]; then
            add_node "dofinv_$id1,$id2" -subfile "dofinv.sub"      \
                                        -var     "target=\"$id1\"" \
                                        -var     "source=\"$id2\""
            add_edge "dofinv_$id1,$id2" "imgreg_$id1,$id2"
            [ ! -f "$dofdir/$id2/$id1.dof.gz" ] || node_done "dofinv_$id1,$id2"
          fi
          info "  Added job `printf '%3d of %d' $n $N`"
        done
      done
    fi
  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}

# ------------------------------------------------------------------------------
# add node for application of pairwise image transformations
transformation_node()
{
  local node=
  local parent=()
  local ids=
  local outdir=
  local ref="$pardir/ref.nii.gz"
  local hdrdofs=
  local dofins=
  local padding=0
  local prefix=
  local suffix='.nii.gz'
  local interp='linear'
  local resample='false'

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)             optargs parent    "$@"; shift ${#parent[@]}; ;;
      -subjects)           optargs ids       "$@"; shift ${#ids[@]}; ;;
      -outdir)             optarg  outdir     $1 "$2"; shift; ;;
      -ref)                optarg  ref        $1 "$2"; shift; ;;
      -prefix)             optarg  prefix     $1 "$2"; shift; ;;
      -suffix)             optarg  suffix     $1 "$2"; shift; ;;
      -hdrdofs)            optarg  hdrdofs    $1 "$2"; shift; ;;
      -dofins)             optarg  dofins     $1 "$2"; shift; ;;
      -bgvalue|-padding)   optarg  padding    $1 "$2"; shift; ;;
      -interp)             optarg  interp     $1 "$2"; shift; ;;
      -include_identity)   resample='true'; ;;
      -*)                  error "transformation_node: invalid option: $1"; ;;
      *)                   [ -z "$node" ] || error "transformation_node: too many arguments"
                           node=$1; ;;
    esac
    shift
  done
  [ -n "$node"       ] || error "transformation_node: missing name argument"
  [ -n "$dofins"     ] || error "transformation_node: missing -dofins argument"
  [ -n "$outdir"     ] || error "transformation_node: missing -outdir argument"
  [ ${#ids[@]} -ge 2 ] || error "transformation_node: not enough -subjects specified"

  # number of pairwise transformations
  local N
  let N="${#ids[@]} * (${#ids[@]} - 1)"

  # add SUBDAG node
  info "Adding node $node..."
  begin_dag $node -splice || {

    local sub

    # create generic transformation submission script
    sub="arguments    = \""
    sub="$sub '$prefix\$(source)$suffix'"
    sub="$sub '$outdir/\$(target)/\$(source)$suffix'"
    [ -z "$hdrdofs" ] || sub="$sub -dof '$hdrdofs/\$(source).dof.gz'"
    sub="$sub -dofin '$dofins/\$(target)/\$(source).dof.gz' -matchInputType -target '$ref' -$interp"
    sub="$sub\""
    sub="$sub\noutput       = $_dagdir/\$(target)/transform_\$(target),\$(source).out"
    sub="$sub\nerror        = $_dagdir/\$(target)/transform_\$(target),\$(source).out"
    sub="$sub\nqueue"
    make_sub_script "transform.sub" "$sub" -executable transformation

    # create generic resample submission script
    if [ $resample == true ]; then
      sub="arguments    = \""
      sub="$sub '$prefix\$(id)$suffix'"
      sub="$sub '$outdir/\$(id)/\$(id)$suffix'"
      [ -z "$hdrdofs" ] || sub="$sub -dof '$hdrdofs/\$(id).dof.gz'"
      sub="$sub -dofin identity -matchInputType -target '$ref' -$interp"
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/\$(id)/resample_\$(id).out"
      sub="$sub\nerror        = $_dagdir/\$(id)/resample_\$(id).out"
      sub="$sub\nqueue"
      make_sub_script "resample.sub" "$sub" -executable transformation
    fi

    # create generic header transformation submission script
    if [ -n "$hdrdofs" ]; then
      sub="arguments    = \""
      sub="$sub '$outdir/\$(target)/\$(source)$suffix'"
      sub="$sub '$outdir/\$(target)/\$(source)$suffix'"
      sub="$sub -dofin_i '$hdrdofs/\$(target).dof.gz'"
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/\$(target)/postalign_\$(target),\$(source).out"
      sub="$sub\nerror        = $_dagdir/\$(target)/postalign_\$(target),\$(source).out"
      sub="$sub\nqueue"
      make_sub_script "postalign.sub" "$sub" -executable headertool
    fi

    # job to create output directories
    local pre=''
    for id in "${ids[@]}"; do
      pre="$pre\nmkdir -p '$_dagdir/$id' || exit 1"
    done
    pre="$pre\n"
    for id in "${ids[@]}"; do
      pre="$pre\nmkdir -p '$outdir/$id' || exit 1"
    done
    make_script "mkdirs.sh" "$pre"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.out\nqueue"

    # add job nodes
    local n t s
    n=0
    t=0
    for id1 in "${ids[@]}"; do
      let t++
      s=0
      for id2 in "${ids[@]}"; do
        let s++
        if [ $t -eq $s ]; then
          [ $resample == true ] || continue
          let n++
          add_node "transform_$id1,$id2" -subfile "resample.sub" -var "id=\"$id1\""
        else
          let n++
          add_node "transform_$id1,$id2" -subfile "transform.sub" -var "target=\"$id1\"" -var "source=\"$id2\""
        fi
        add_edge "transform_$id1,$id2" 'mkdirs'
        if [ -n "$hdrdofs" ]; then
          add_node "postalign_$id1,$id2" -subfile "postalign.sub" -var "target=\"$id1\"" -var "source=\"$id2\""
          add_edge "postalign_$id1,$id2" "transform_$id1,$id2"
        fi
        [ ! -f "$outdir/$id1/$id2$suffix" ] || {
          node_done "transform_$id1,$id2"
          [ -z "$hdrdofs" ] || node_done "postalign_$id1,$id2"
        }
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

  info "Adding node $node..."
  begin_dag $node -splice || {

    # weights of input transformations
    if [ -z "$doflst" ]; then
      [ ${#ids[@]} -gt 0 ] || error "dofaverage_node: missing -subjects or -doflst argument"
      local dofnames=
      for id in "${ids[@]}"; do
        dofnames="$dofnames$id\t1\n"
      done
      doflst="$_dagdir/dofavg.par"
      write "$doflst" "$dofnames"
    elif [ ${#ids[@]} -eq 0 ]; then
      read_sublst ids "$doflst"
    fi

    # create generic dofaverage submission script
    local sub="arguments = \"'$dofdir/\$(id).dof.gz' -all$options -add-identity-for-dofname '\$(id)'"
    sub="$sub -dofdir '$dofins' -dofnames '$doflst' -prefix '\$(id)/' -suffix .dof.gz"
    sub="$sub\""
    sub="$sub\noutput    = $_dagdir/dofavg_\$(id).out"
    sub="$sub\nerror     = $_dagdir/dofavg_\$(id).out"
    sub="$sub\nqueue"
    make_sub_script "dofavg.sub" "$sub" -executable dofaverage

    # node to create output directories
    if [ -n "$dofdir" ]; then
      make_script "mkdirs.sh" "mkdir -p '$dofdir' || exit 1"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.out\nqueue"
    fi

    # add dofaverage nodes to DAG
    for id in "${ids[@]}"; do
      add_node "dofavg_$id" -subfile "dofavg.sub" -var "id=\"$id\""
      add_edge "dofavg_$id" 'mkdirs'
      [ ! -f "$dofdir/$id.dof.gz" ] || node_done "dofavg_$id"
    done

  }; end_dag
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
  begin_dag $node -splice || {

    # create generic dofcombine submission script
    local sub="arguments = \"'$dofdir1/\$(id).dof.gz' '$dofdir2/\$(id).dof.gz' '$dofdir3/\$(id).dof.gz'$options\""
    sub="$sub\noutput    = $_dagdir/dofcat_\$(id).out"
    sub="$sub\nerror     = $_dagdir/dofcat_\$(id).out"
    sub="$sub\nqueue"
    make_sub_script "dofcat.sub" "$sub" -executable dofcombine

    # node to create output directories
    make_script "mkdirs.sh" "mkdir -p '$dofdir3' || exit 1"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.out\nqueue"

    # add dofaverage nodes to DAG
    for id in "${ids[@]}"; do
      add_node "dofcat_$id" -subfile "dofcat.sub" -var "id=\"$id\""
      add_edge "dofcat_$id" 'mkdirs'
      [ ! -f "$dofdir3/$id.dof.gz" ] || node_done "dofcat_$id"
    done

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}

# ------------------------------------------------------------------------------
# add node for composition of linear and global transformations
ffdcompose_node()
{
  local node=
  local parent=()
  local ids=()
  local idlst=()
  local dofdir1=
  local dofdir2=
  local dofdir3=

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids    "$@"; shift ${#ids[@]}; ;;
      -sublst)   optarg  idlst   $1 "$2"; shift; ;;
      -dofdir1)  optarg  dofdir1 $1 "$2"; shift; ;;
      -dofdir2)  optarg  dofdir2 $1 "$2"; shift; ;;
      -dofdir3)  optarg  dofdir3 $1 "$2"; shift; ;;
      -*)        error "ffdcompose_node: invalid option: $1"; ;;
      *)         [ -z "$node" ] || error "ffdcompose_node: too many arguments"
                 node=$1; ;;
    esac
    shift
  done
  [ -n "$node"    ] || error "ffdcompose_node: missing name argument"
  [ -n "$dofdir1" ] || error "ffdcompose_node: missing -dofdir1 argument"
  [ -n "$dofdir2" ] || error "ffdcompose_node: missing -dofdir2 argument"
  [ -n "$dofdir3" ] || error "ffdcompose_node: missing -dofdir3 argument"

  info "Adding node $node..."
  begin_dag $node -splice || {

    # read IDs from specified text file
    [ ${#ids[@]} -gt 0 ] || read_sublst ids "$idlst"

    # create generic dofaverage submission script
    local sub="arguments = \"'$dofdir1/\$(id).dof.gz' '$dofdir2/\$(id).dof.gz' '$dofdir3/\$(id).dof.gz'\""
    sub="$sub\noutput    = $_dagdir/dofcat_\$(id).out"
    sub="$sub\nerror     = $_dagdir/dofcat_\$(id).out"
    sub="$sub\nqueue"
    make_sub_script "dofcat.sub" "$sub" -executable ffdcompose

    # node to create output directories
    make_script "mkdirs.sh" "mkdir -p '$dofdir3' || exit 1"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.out\nqueue"

    # add dofaverage nodes to DAG
    for id in "${ids[@]}"; do
      add_node "dofcat_$id" -subfile "dofcat.sub" -var "id=\"$id\""
      add_edge "dofcat_$id" 'mkdirs'
      [ ! -f "$dofdir3/$id.dof.gz" ] || node_done "dofcat_$id"
    done

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}

# ------------------------------------------------------------------------------
# add node for computation of average image
average_node()
{
  local node=
  local parent=()
  local ids=()
  local idlst=()
  local imgdir=
  local imgpre=
  local imgsuf='.nii.gz'
  local dofdir=
  local dofpre=
  local dofsuf='.dof.gz'
  local average=
  local options=
  local label margin bgvalue

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids    "$@"; shift ${#ids[@]}; ;;
      -sublst)   optarg  idlst   $1 "$2"; shift; ;;
      -imgdir)   optarg  imgdir  $1 "$2"; shift; ;;
      -imgpre)   optarg  imgpre  $1 "$2"; shift; ;;
      -imgsuf)   optarg  imgsuf  $1 "$2"; shift; ;;
      -dofdir)   optarg  dofdir  $1 "$2"; shift; ;;
      -dofpre)   optarg  dofpre  $1 "$2"; shift; ;;
      -dofsuf)   optarg  dofsuf  $1 "$2"; shift; ;;
      -output)   optarg  average $1 "$2"; shift; ;;
      -voxelwise) options="$options -voxelwise"; ;;
      -margin)   optarg  margin  $1 "$2"; shift; options="$options -margin $margin";;
      -bgvalue)  optarg  bgvalue $1 "$2"; shift; options="$options -padding $bgvalue";;
      -label)    optarg  label   $1 "$2"; shift; options="$options -label $label";;
      -*)        error "average_node: invalid option: $1"; ;;
      *)         [ -z "$node" ] || error "average_node: too many arguments"
                 node="$1"; ;;
    esac
    shift
  done
  [ -n "$node"    ] || error "average_node: missing name argument"
  [ -n "$average" ] || error "average_node: missing -image argument"
  [ -z "$imgdir"  ] || imgpre="$imgdir/$imgpre"
  [ -z "$dofdir"  ] || dofpre="$dofdir/$dofpre"

  info "Adding node $node..."
  begin_dag $node -splice || {

    # write image list with optional transformations and weights
    local imglst="$_dagdir/imgavg.par"
    local images="$topdir\n"
    if [ -n "$idlst" ]; then
      [ ${#ids[@]} -eq 0 ] || error "average_node: options -subjects and -sublst are mutually exclusive"
      local pair id weight
      while read line; do
        pair=($line)
        id=${pair[0]}
        weight=${pair[1]}
        images="$images$imgpre$id$imgsuf"
        [ -z "$dofdir" ] || images="$images $dofpre$id$dofsuf"
        [ -z "$weight" ] || images="$images $weight"
        images="$images\n"
      done < "$idlst"
    else
      for id in "${ids[@]}"; do
        images="$images$imgpre$id$imgsuf"
        [ -z "$dofdir" ] || images="$images $dofpre$id$dofsuf"
        images="$images\n"
      done
    fi
    write "$imglst" "$images"

    # node to create output directories
    make_script "mkdirs.sh" "mkdir -p '$(dirname "$average")' || exit 1"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.out\nqueue"

    # add average node to DAG
    local sub="arguments = \"$average -images '$imglst'$options\""
    sub="$sub\noutput    = $_dagdir/average.out"
    sub="$sub\nerror     = $_dagdir/average.out"
    sub="$sub\nqueue"
    add_node "average" -sub "$sub" -executable average
    add_edge "average" 'mkdirs'
    [ ! -f "$average" ] || node_done average

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}
