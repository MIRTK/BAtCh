################################################################################
#
################################################################################

[ -z $__daggen_mirtk_sh ] || return 0
__daggen_mirtk_sh=0

# ------------------------------------------------------------------------------
# import modules
_moddir="$(dirname "$BASH_SOURCE")"
source "$_moddir/dag.sh" || {
  echo "Failed to import daggen/dag module!" 1>&2
  exit 1
}

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
register_node()
{
  local node=
  local parent=()
  local refid=
  local refdir=
  local mask=
  local ids=
  local model=
  local resolution=
  local levels=(4 1)
  local similarity='NMI'
  local hdrdofs=
  local hdrdof_opt='-dof'
  local dofins=
  local dofdir=
  local params=
  local padding=
  local segments=()
  local segdir=
  local ic='false'
  local sym='false'

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)     optargs parent  "$@"; shift ${#parent[@]}; ;;
      -refid)      optarg  refid    $1 "$2"; shift; ;;
      -refdir)     optarg  refdir   $1 "$2"; shift; ;;
      -mask)       optarg  mask     $1 "$2"; shift; ;;
      -subjects)   optargs ids     "$@"; shift ${#ids[@]}; ;;
      -model)      optarg  model    $1 "$2"; shift; ;;
      -hdrdofs)    optarg  hdrdofs  $1 "$2"; shift; hdrdof_opt='-dof'; ;;
      -invhdrdofs) optarg  hdrdofs  $1 "$2"; shift; hdrdof_opt='-dof_i'; ;;
      -dofins)     optarg  dofins   $1 "$2"; shift; ;;
      -dofdir)     optarg  dofdir   $1 "$2"; shift; ;;
      -levels)
        optargs levels "$@"
        if [ ${#levels[@]} -gt 2 ]; then
          error "register_node: too many arguments for option: $1"
        fi
        shift ${#levels[@]}
        if [ ${#levels[@]} -eq 1 ]; then
          levels=("${levels[0]}" 1)
        fi
        ;;
      -maxres)           optarg  resolution $1 "$2"; shift; ;;
      -similarity|-sim)  optarg  similarity $1 "$2"; shift; ;;
      -bgvalue|-padding) optarg  padding    $1 "$2"; shift; ;;
      -par)
        local args
        optargs args "$@"
        if [ ${#args[@]} -ne 2 ]; then
          error "register_node: option requires two arguments: $1"
        fi
        shift 2
        params="$params\n${args[0]} = ${args[1]}"
        ;;
      -segdir)
        optarg segdir $1 "$2"
        shift
        ;;
      -segssd)
        local segment
        optargs segment "$@"
        if [ ${#segment[@]} -gt 2 ]; then
          error "register_node: too many arguments for option: $1"
        fi
        shift ${#segment[@]}
        if [ ${#segment[@]} -eq 1 ]; then
          segment=("${segment[0]}" 1)
        fi
        segments=("${segments[@]}" "${segment[@]}")
        ;;
      -inverse-consistent)
        ic='true'
        ;;
      -symmetric)
        ic='true'; sym='true'
        ;;
      -*)
        error "register_node: invalid option: $1"
        ;;
      *)
        [ -z "$node" ] || error "register_node: too many arguments"
        node=$1
        ;;
    esac
    shift
  done
  [ -n "$node"       ] || error "register_node: missing name argument"
  [ -n "$model"      ] || error "register_node: missing -model argument"
  [ ${#ids[@]} -ge 2 ] || [ ${#ids[@]} -gt 0 -a -n "$refid" ] || error "register_node: not enough -subjects specified"

  if [ ${levels[0]} -lt ${levels[1]} ]; then
    error "register_node: invalid -levels arguments, first level must be greater than final level"
  fi
  if [ ${#segments[@]} -ne 0 -a -z "$segdir" ]; then
    error "register_node: -segdir option required when -segssd option given"
  fi
  local nlevels=${levels[0]}
  if [ -n "$resolution" ]; then
    let nlevels="${levels[0]} - ${levels[1]} + 1"
    resolution=$('/usr/bin/bc' -l <<< "2^(${levels[1]}-1) * $resolution")
    resolution=$(remove_trailing_zeros $resolution)
    levels=($nlevels 1)
  fi

  local i j t s
  local fidelity=''
  if [ $sym = 'true' ]; then
    fidelity='SIM[Image similarity](I(1) o T^-.5, I(2) o T^.5)'
  elif [ $ic = 'true' ]; then
    fidelity='SIM[Fwd image similarity](I(1), I(2) o T) + SIM[Bwd image similarity](I(1) o T^-1, I(2))'
  else
    fidelity='SIM[Image similarity](I(1), I(2) o T)'
  fi
  i=0
  while [ $i -lt ${#segments[@]} ]; do
    let j="$i + 1"
    let t="$i + 3"
    let s="$i + 4"
    if [ $sym = 'true' ]; then
      fidelity="$fidelity + ${segments[j]} SSD[${segments[i]} difference](I($t) o T^-.5, I($s) o T^.5)"
    elif [ $ic = 'true' ]; then
      fidelity="$fidelity + ${segments[j]} SSD[Fwd ${segments[i]} difference](I($t), I($s) o T)"
      fidelity="$fidelity + ${segments[j]} SSD[Bwd ${segments[i]} difference](I($t) o T^-1, I($s))"
    else
      fidelity="$fidelity + ${segments[j]} SSD[${segments[i]} difference](I($t), I($s) o T)"
    fi
    let i="$i + 2"
  done

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
    local cfg="[default]"
    cfg="$cfg\nTransformation model             = $model"
    cfg="$cfg\nImage interpolation mode         = Fast linear with padding"
    cfg="$cfg\nEnergy function                  = $fidelity + 0 BE[Bending energy] + 0 JAC[Jacobian penalty]"
    cfg="$cfg\nSimilarity measure               = $similarity"
    cfg="$cfg\nNo. of bins                      = 64"
    cfg="$cfg\nLocal window size [box]          = 5 vox"
    cfg="$cfg\nMaximum streak of rejected steps = 1"
    cfg="$cfg\nStrict step length range         = No"
    cfg="$cfg\nNo. of resolution levels         = $nlevels"
    cfg="$cfg\nFinal resolution level           = ${levels[1]}"
    if [ -n "$padding" ]; then
      cfg="$cfg\nPadding value of image 1         = $padding"
      cfg="$cfg\nPadding value of image 2         = $padding"
    fi
    #if [ ${#segments[@]} -ne 0 ]; then
    #  i=0
    #  while [ $i -lt ${#segments[@]} ]; do
    #    let j="$i + 3"
    #    cfg="$cfg\nPadding value of image $j = -1"
    #    let i++
    #  done
    #fi
    cfg="$cfg\n$params\n"

    if [ -n "$resolution" ]; then
      cfg="$cfg\n"
      local lvl res
      lvl=1
      while [ $lvl -le ${levels[0]} ]; do
        cfg="$cfg\n\n[level $lvl]"
        res=$('/usr/bin/bc' -l <<< "2^($lvl-1) * $resolution")
        res=$(remove_trailing_zeros $res)
        cfg="$cfg\nResolution = $res"
        let lvl++
      done
    fi

    if [ ${#segments[@]} -ne 0 ]; then
      cfg="$cfg\n"
      local lvl blr
      lvl=1
      while [ $lvl -le ${levels[0]} ]; do
        cfg="$cfg\n\n[level $lvl]"
        blr=(2 2) # blurring of binary mask
        if [ -n "$refid" -a -n "$refdir" ]; then
          blr[0]=1 # reference usually a probabilistic map (i.e., a bit blurry)
        fi
        i=0
        while [ $i -lt ${#segments[@]} ]; do
          let j="$i + 1"
          let t="$i + 3"
          let s="$i + 4"
          cfg="$cfg\nBlurring of image $t = ${blr[0]} vox"
          cfg="$cfg\nBlurring of image $s = ${blr[1]} vox"
          let i="$i + 2"
        done
        let lvl++
      done
    fi

    parin="$_dagdir/imgreg.cfg"
    write "$parin" "$cfg\n"

    # create generic registration submission script
    local sub="arguments    = \""
    if [ -n "$refid" -a -n "$refdir" ]; then
      if [ -n "$hdrdofs" ]; then
        sub="$sub -image '$refdir/$refpre\$(target)$refsuf' -image '$imgdir/$imgpre\$(source)$imgsuf'"
        sub="$sub $hdrdof_opt '$hdrdofs/\$(source).dof.gz'"
        i=0
        while [ $i -lt ${#segments[@]} ]; do
          sub="$sub -image '$refdir/$refpre\$(target)-${segments[i]}$refsuf' -image '$segdir/${segments[i]}/$segpre\$(source)$segsuf'"
          sub="$sub $hdrdof_opt '$hdrdofs/\$(source).dof.gz'"
          let i="$i + 2"
        done
      else
        sub="$sub -image '$refdir/$refpre\$(target)$refsuf' -image '$imgdir/$imgpre\$(source)$imgsuf'"
        i=0
        while [ $i -lt ${#segments[@]} ]; do
          sub="$sub -image '$refdir/$refpre\$(target)-${segments[i]}$refsuf' -image '$segdir/${segments[i]}/$segpre\$(source)$segsuf'"
          let i="$i + 2"
        done
      fi
    else
      if [ -n "$hdrdofs" ]; then
        sub="$sub -image '$imgdir/$imgpre\$(target)$imgsuf'"
        [ -n "$refid" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(target).dof.gz'"
        sub="$sub -image '$imgdir/$imgpre\$(source)$imgsuf' $hdrdof_opt '$hdrdofs/\$(source).dof.gz'"
        i=0
        while [ $i -lt ${#segments[@]} ]; do
          sub="$sub -image '$segdir/${segments[i]}/$segpre\$(target)$segsuf'"
          [ -n "$refid" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(target).dof.gz'"
          sub="$sub -image '$segdir/${segments[i]}/$segpre\$(source)$segsuf' $hdrdof_opt '$hdrdofs/\$(source).dof.gz'"
          let i="$i + 2"
        done
      else
        sub="$sub -image '$imgdir/$imgpre\$(target)$imgsuf' -image '$imgdir/$imgpre\$(source)$imgsuf'"
        i=0
        while [ $i -lt ${#segments[@]} ]; do
          sub="$sub -image '$segdir/${segments[i]}/$segpre\$(target)$segsuf' -image '$segdir/${segments[i]}/$segpre\$(source)$segsuf'"
          let i="$i + 2"
        done
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
    sub="$sub -parin '$parin' -parout '$_dagdir/\$(target)/imgreg_\$(target),\$(source).cfg'"
    sub="$sub\""
    sub="$sub\noutput       = $_dagdir/\$(target)/imgreg_\$(target),\$(source).log"
    sub="$sub\nerror        = $_dagdir/\$(target)/imgreg_\$(target),\$(source).log"
    sub="$sub\nqueue"
    make_sub_script "imgreg.sub" "$sub" -executable register

    # create generic dofinvert submission script
    if [[ $ic == true ]] && [ -z "$refid" ] ; then
      # command used to invert inverse-consistent transformation
      local sub="arguments    = \"'$dofdir/\$(target)/\$(source).dof.gz' '$dofdir/\$(source)/\$(target).dof.gz'\""
      sub="$sub\noutput       = $_dagdir/\$(target)/dofinv_\$(target),\$(source).log"
      sub="$sub\nerror        = $_dagdir/\$(target)/dofinv_\$(target),\$(source).log"
      sub="$sub\nqueue"
      make_sub_script "dofinv.sub" "$sub" -executable invert-dof
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
                      -sub        "error = $_dagdir/mkdirs.log\nqueue"

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
transform_image_node()
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
      -*)                  error "transform_image_node: invalid option: $1"; ;;
      *)                   [ -z "$node" ] || error "transform_image_node: too many arguments"
                           node=$1; ;;
    esac
    shift
  done
  [ -n "$node"       ] || error "transform_image_node: missing name argument"
  [ -n "$dofins"     ] || error "transform_image_node: missing -dofins argument"
  [ -n "$outdir"     ] || error "transform_image_node: missing -outdir argument"
  [ ${#ids[@]} -ge 2 ] || error "transform_image_node: not enough -subjects specified"

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
    sub="$sub -dofin '$dofins/\$(target)/\$(source).dof.gz' -target '$ref' -$interp"
    sub="$sub\""
    sub="$sub\noutput       = $_dagdir/\$(target)/transform_\$(target),\$(source).log"
    sub="$sub\nerror        = $_dagdir/\$(target)/transform_\$(target),\$(source).log"
    sub="$sub\nqueue"
    make_sub_script "transform.sub" "$sub" -executable transform-image

    # create generic resample submission script
    if [ $resample == true ]; then
      sub="arguments    = \""
      sub="$sub '$prefix\$(id)$suffix'"
      sub="$sub '$outdir/\$(id)/\$(id)$suffix'"
      [ -z "$hdrdofs" ] || sub="$sub -dof '$hdrdofs/\$(id).dof.gz'"
      sub="$sub -dofin identity -target '$ref' -$interp"
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/\$(id)/resample_\$(id).log"
      sub="$sub\nerror        = $_dagdir/\$(id)/resample_\$(id).log"
      sub="$sub\nqueue"
      make_sub_script "resample.sub" "$sub" -executable transform-image
    fi

    # create generic header transformation submission script
    if [ -n "$hdrdofs" ]; then
      sub="arguments    = \""
      sub="$sub '$outdir/\$(target)/\$(source)$suffix'"
      sub="$sub '$outdir/\$(target)/\$(source)$suffix'"
      sub="$sub -dofin_i '$hdrdofs/\$(target).dof.gz'"
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/\$(target)/postalign_\$(target),\$(source).log"
      sub="$sub\nerror        = $_dagdir/\$(target)/postalign_\$(target),\$(source).log"
      sub="$sub\nqueue"
      make_sub_script "postalign.sub" "$sub" -executable edit-image
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
                      -sub        "error = $_dagdir/mkdirs.log\nqueue"

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
    sub="$sub\noutput    = $_dagdir/dofavg_\$(id).log"
    sub="$sub\nerror     = $_dagdir/dofavg_\$(id).log"
    sub="$sub\nqueue"
    make_sub_script "dofavg.sub" "$sub" -executable average-dofs

    # node to create output directories
    if [ -n "$dofdir" ]; then
      make_script "mkdirs.sh" "mkdir -p '$dofdir' || exit 1"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
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

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids    "$@"; shift ${#ids[@]}; ;;
      -dofdir1)  optarg  dofdir1 $1 "$2"; shift; ;;
      -dofdir2)  optarg  dofdir2 $1 "$2"; shift; ;;
      -dofdir3)  optarg  dofdir3 $1 "$2"; shift; ;;
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
    local sub="arguments = \"'$dofdir1/\$(id).dof.gz' '$dofdir2/\$(id).dof.gz' '$dofdir3/\$(id).dof.gz'\""
    sub="$sub\noutput    = $_dagdir/dofcat_\$(id).log"
    sub="$sub\nerror     = $_dagdir/dofcat_\$(id).log"
    sub="$sub\nqueue"
    make_sub_script "dofcat.sub" "$sub" -executable compose-dofs

    # node to create output directories
    make_script "mkdirs.sh" "mkdir -p '$dofdir3' || exit 1"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.log\nqueue"

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
    sub="$sub\noutput    = $_dagdir/dofcat_\$(id).log"
    sub="$sub\nerror     = $_dagdir/dofcat_\$(id).log"
    sub="$sub\nqueue"
    make_sub_script "dofcat.sub" "$sub" -executable compose-dofs

    # node to create output directories
    make_script "mkdirs.sh" "mkdir -p '$dofdir3' || exit 1"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.log\nqueue"

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
  local reference=
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
      -reference) optarg reference $1 "$2"; shift; ;;
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
  [ -z "$reference" ] || options="$options -reference $reference"

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
                      -sub        "error = $_dagdir/mkdirs.log\nqueue"

    # add average node to DAG
    local sub="arguments = \"$average -images '$imglst'$options\""
    sub="$sub\noutput    = $_dagdir/average.log"
    sub="$sub\nerror     = $_dagdir/average.log"
    sub="$sub\nqueue"
    add_node "average" -sub "$sub" -executable average-images
    add_edge "average" 'mkdirs'
    [ ! -f "$average" ] || node_done average

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}
