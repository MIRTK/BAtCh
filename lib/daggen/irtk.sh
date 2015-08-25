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
  local tgtdir=
  local tgtid=
  local tgtpre=
  local tgtsuf='.nii.gz'
  local srcdir=
  local srcid=
  local srcpre=
  local srcsuf='.nii.gz'
  local mask=
  local ids=
  local imgdir=
  local imgpre=
  local imgsuf='.nii.gz'
  local model=
  local mask=
  local fidelity='SIM[Similarity](I(1), I(2) o T)'
  local similarity='NMI'
  local hdrdofs=
  local hdrdof_opt='-dof'
  local dofins=
  local dofdir=
  local dofid=
  local dofsuf='.dof.gz'
  local params=
  local bgvalue=-32767
  local padding=-32767
  local ic='false'
  local group=1

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)             optargs parent    "$@"; shift ${#parent[@]}; ;;
      -tgtid|-refid)       tgtid="$2";  shift; ;;
      -srcid)              srcid="$2";  shift; ;;
      -tgtdir|-refdir)     tgtdir="$2"; shift; ;;
      -srcdir)             tgtdir="$2"; shift; ;;
      -tgtpre|-refpre)     tgtpre="$2"; shift; ;;
      -srcpre)             srcpre="$2"; shift; ;;
      -imgpre)             imgpre="$2"; shift; ;;
      -tgtsuf|-refsuf)     tgtsuf="$2"; shift; ;;
      -srcsuf)             srcsuf="$2"; shift; ;;
      -imgsuf)             optarg  imgsuf     $1 "$2"; shift; ;;
      -imgdir)             optarg  imgdir     $1 "$2"; shift; ;;
      -mask)               optarg  mask       $1 "$2"; shift; ;;
      -subjects)           optargs ids       "$@"; shift ${#ids[@]}; ;;
      -model)              optarg  model      $1 "$2"; shift; ;;
      -hdrdofs)            optarg  hdrdofs    $1 "$2"; shift; hdrdof_opt='-dof'; ;;
      -invhdrdofs)         optarg  hdrdofs    $1 "$2"; shift; hdrdof_opt='-dof_i'; ;;
      -dofins)             optarg  dofins     $1 "$2"; shift; ;;
      -dofdir)             optarg  dofdir     $1 "$2"; shift; ;;
      -dofid)              optarg  dofid      $1 "$2"; shift; ;;
      -dofsuf)             optarg  dofsuf     $1 "$2"; shift; ;;
      -par)                optarg  param      $1 "$2"; shift; params="$params\n$param"; ;;
      -similarity)         optarg  similarity $1 "$2"; shift; ;;
      -bgvalue)            optarg  bgvalue    $1 "$2"; shift; ;;
      -padding)            optarg  padding    $1 "$2"; shift; ;;
      -inverse-consistent) ic='true'; fidelity='0.5 SIM[Forward similarity](I(1), I(2) o T) + 0.5 SIM[Backward similarity](I(1) o T^-1, I(2))'; ;;
      -symmetric)          ic='true'; fidelity='SIM[Similarity](I(1) o T^-0.5, I(2) o T^0.5)'; ;;
      -group)              optarg group $1 "$2"; shift; ;;
      -*)                  error "ireg_node: invalid option: $1"; ;;
      *)                   [ -z "$node" ] || error "ireg_node: too many arguments"
                           node=$1; ;;
    esac
    shift
  done
  [ -n "$node"       ] || error "ireg_node: missing name argument"
  [ -n "$model"      ] || error "ireg_node: missing -model argument"
  [ ${#ids[@]} -ge 2 ] || [ ${#ids[@]} -gt 0 -a -n "$tgtid$srcid" ] || error "ireg_node: not enough -subjects specified"
  if [ -n "$dofid" ]; then
    if [ -z "$tgtid" -o -z "$srcid" ]; then
      error "ireg_node: -dofid requires a fixed -tgtid and -srcid"
    fi
  else
    if [ -n "$tgtid" -a -n "$srcid" ]; then
      error "ireg_node: -dofid required when -tgtid and -srcid are fixed"
    fi
  fi
  [ -n "$tgtdir"                ] || tgtdir="$imgdir"
  [ -n "$tgtpre" -o -n "$tgtid" ] || tgtpre="$imgpre"
  [ -n "$tgtsuf"                ] || tgtsuf="$imgsuf"
  [ -n "$srcdir"                ] || srcdir="$imgdir"
  [ -n "$srcpre" -o -n "$srcid" ] || srcpre="$imgpre"
  [ -n "$srcsuf"                ] || srcsuf="$imgsuf"

  local interp='Fast linear'
  [ $padding -eq -32767 ] || interp="$interp with padding"

  # number of registrations
  local N
  if [ -n "$dofid" ]; then
    N=1
  elif [ -n "$tgtid" -o -n "$srcid" ]; then
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
    cfg="$cfg\nBackground value                 = $bgvalue"
    cfg="$cfg\nPadding value                    = $padding"
    cfg="$cfg\nInterpolation mode               = $interp"
    cfg="$cfg\nMaximum streak of rejected steps = 1"
    cfg="$cfg\nStrict step length range         = No"
    cfg="$cfg\nNo. of bins                      = 64"
    cfg="$cfg\n$params"
    parin="$_dagdir/ireg.cfg"
    write "$parin" "$cfg\n"

    # create generic ireg submission script
    local sub="arguments    = \""
    [ -z "$mask" ] || sub="$sub -mask '$mask'"
    sub="$sub -parin '$parin'"
    if [ -n "$tgtid" -a -n "$srcid" ]; then
      sub="$sub -parout '$_dagdir/ireg_$tgtid,$srcid.par'"
      sub="$sub -image '$tgtdir/$tgtpre$tgtid$tgtsuf' -image '$srcdir/$srcpre$srcid$srcsuf'"
      sub="$sub -dofout '$dofdir/$dofid$dofsuf'"
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/imgreg_$tgtid,$srcid.out"
      sub="$sub\nerror        = $_dagdir/imgreg_$tgtid,$srcid.out"
    elif [ -n "$tgtid" ]; then
      sub="$sub -parout '$_dagdir/ireg_\$(source).par'"
      sub="$sub -image '$tgtdir/$tgtpre$tgtid$tgtsuf' -image '$imgdir/$imgpre\$(source)$imgsuf'"
      [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(source)$dofsuf'"
      if [[ "$dofins" == "Id" ]]; then
        sub="$sub -dofin Id"
      elif [ -n "$dofins" ]; then
        sub="$sub -dofin '$dofins/\$(source)$dofsuf'"
      fi
      [ -z "$dofdir" ] || sub="$sub -dofout '$dofdir/\$(source)$dofsuf'"
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/imgreg_\$(source).out"
      sub="$sub\nerror        = $_dagdir/imgreg_\$(source).out"
    elif [ -n "$srcid" ]; then
      sub="$sub -parout '$_dagdir/ireg_\$(target).par'"
      sub="$sub -image '$imgdir/$imgpre\$(target)$imgsuf'"
      [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(target)$dofsuf'"
      sub="$sub -image '$srcdir/$srcpre$srcid$srcsuf'"
      if [[ "$dofins" == "Id" ]]; then
        sub="$sub -dofin Id"
      elif [ -n "$dofins" ]; then
        sub="$sub -dofin '$dofins/\$(target)$dofsuf'"
      fi
      [ -z "$dofdir" ] || sub="$sub -dofout '$dofdir/\$(target)$dofsuf'"
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/imgreg_\$(target).out"
      sub="$sub\nerror        = $_dagdir/imgreg_\$(target).out"
    else
      sub="$sub -parout '$_dagdir/\$(target)/ireg_\$(target),\$(source).par'"
      if [ -n "$hdrdofs" ]; then
        sub="$sub -image '$imgdir/$imgpre\$(target)$imgsuf' $hdrdof_opt '$hdrdofs/\$(target)$dofsuf'"
        sub="$sub -image '$imgdir/$imgpre\$(source)$imgsuf' $hdrdof_opt '$hdrdofs/\$(source)$dofsuf'"
      else
        sub="$sub -image '$imgdir/$imgpre\$(target)$imgsuf' -image '$imgdir/$imgpre\$(source)$imgsuf'"
      fi
      [ -z "$dofdir" ] || sub="$sub -dofout '$dofdir/\$(target)/\$(source)$dofsuf'"
      if [[ "$dofins" == "Id" ]]; then
        sub="$sub -dofin Id"
      elif [ -n "$dofins" ]; then
        sub="$sub -dofin '$dofins/\$(target)/\$(source)$dofsuf'"
      fi
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/\$(target)/imgreg_\$(target),\$(source).out"
      sub="$sub\nerror        = $_dagdir/\$(target)/imgreg_\$(target),\$(source).out"
    fi
    sub="$sub\nqueue"
    make_sub_script "imgreg.sub" "$sub" -executable ireg

    # create generic dofinvert submission script
    if [[ $ic == true ]] && [ -z "$tgtid" -a -z "$srcid" ] ; then
      # command used to invert inverse-consistent transformation
      local sub="arguments    = \"'$dofdir/\$(target)/\$(source)$dofsuf' '$dofdir/\$(source)/\$(target)$dofsuf'\""
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
    if [ -n "$tgtid" -o -n "$srcid" ]; then
      # directory for output files
      if [ -n "$dofdir" ]; then
        pre="$pre\nmkdir -p '$dofdir' || exit 1"
      fi
    else
      # directory for log files
      for id in "${ids[@]}"; do
        pre="$pre\nmkdir -p '$_dagdir/$id' || exit 1"
      done
      # directory for output files
      if [ -n "$dofdir" ]; then
        pre="$pre\n"
        for id in "${ids[@]}"; do
          pre="$pre\nmkdir -p '$dofdir/$id' || exit 1"
        done
      fi
    fi
    if [ -n "$pre" ]; then
      make_script "mkdirs.sh" "$pre"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.out\nqueue"
    fi

    local i j n t s is_done
    # add node to register target to source
    if [ -n "$tgtid" -a -n "$srcid" ]; then
      n=1
      add_node "imgreg_$tgtid,$srcid" -subfile "imgreg.sub"
      [ -z "$pre" ] || add_edge "imgreg_$tgtid,$srcid" 'mkdirs'
      [ ! -f "$dofdir/$dofid$dofsuf" ] || node_done "imgreg_$tgtid,$srcid"
    # add nodes to register subject images to common reference
    elif [ -n "$tgtid" ]; then
      if [ $group -gt 1 ]; then
        i=1
        while [ $i -le ${#ids[@]} ]; do
          let j=$i+$group-1
          add_node "imgreg_$i-$j" -subfile "imgreg.sub" -grpvar source -grpval ${ids[@]:$i-1:$group}
          [ -z "$pre" ] || add_edge "imgreg_$i-$j" 'mkdirs'
          is_done='true'
          for id in ${ids[@]:$i:$group}; do
            if [ ! -f "$dofdir/$id$dofsuf" ]; then
              is_done='false'
              break
            fi
          done
          [[ $is_done == false ]] || node_done "imgreg_$i-$j"
          let i="$j+1"
        done
      else
        n=0
        for id in "${ids[@]}"; do
          let n++
          add_node "imgreg_$id" -subfile "imgreg.sub" -var "source=\"$id\""
          [ -z "$pre" ] || add_edge "imgreg_$id" 'mkdirs'
          [ ! -f "$dofdir/$id$dofsuf" ] || node_done "imgreg_$id"
        done
      fi
    # add nodes to register common reference to subject images
    elif [ -n "$srcid" ]; then
      if [ $group -gt 1 ]; then
        i=1
        while [ $i -le ${#ids[@]} ]; do
          let j=$i+$group-1
          add_node "imgreg_$i-$j" -subfile "imgreg.sub" -grpvar target -grpval ${ids[@]:$i-1:$group}
          [ -z "$pre" ] || add_edge "imgreg_$i-$j" 'mkdirs'
          is_done='true'
          for id in ${ids[@]:$i:$group}; do
            if [ ! -f "$dofdir/$id$dofsuf" ]; then
              is_done='false'
              break
            fi
          done
          [[ $is_done == false ]] || node_done "imgreg_$i-$j"
          let i="$j+1"
        done
      else
        n=0
        for id in "${ids[@]}"; do
          let n++
          add_node "imgreg_$id" -subfile "imgreg.sub" -var "target=\"$id\""
          [ -z "$pre" ] || add_edge "imgreg_$id" 'mkdirs'
          [ ! -f "$dofdir/$id$dofsuf" ] || node_done "imgreg_$id"
        done
      fi
    # add pairwise registration nodes
    else
      n=0
      t=0
      local s1 s2 S i grpids
      for id1 in "${ids[@]}"; do
        let t++
        # register all other images to image of subject id1
        if [ $group -gt 1 ]; then
          s1=1
          if [[ $ic == true ]]; then
            let S="$t-1"
          else
            let S=${#ids[@]}
          fi
          i=0
          while [ $s1 -le $S ]; do
            s=$s1
            srcids=()
            let s2="$s1+$group-1"
            if [[ $ic == true ]]; then
              while [ $s -le $s2 ]; do
                [ $s -ge $t ] || srcids=("${srcids[@]}" "${ids[$s-1]}")
                let s++
              done
            else
              while [ $s -le $s2 ]; do
                [ $s -eq $t ] || srcids=("${srcids[@]}" "${ids[$s-1]}")
                let s++
              done
            fi
            if [ ${#srcids[@]} -gt 0 ]; then
              let i++
              let n++
              # node to register id1 and id2
              add_node "imgreg_$id1-$i" -subfile "imgreg.sub" \
                                        -var     "target=\"$id1\"" \
                                        -grpvar source -grpval ${srcids[@]}
              add_edge "imgreg_$id1-$i" 'mkdirs'
              is_done='true'
              for id2 in ${srcids[@]}; do
                if [ ! -f "$dofdir/$id1/$id2$dofsuf" ]; then
                  is_done='false'
                  break
                fi
              done
              [[ $is_done == false ]] || node_done "imgreg_$id1-$i"
              # node to invert inverse-consistent transformation
              if [[ $ic == true ]] && [ -n "$dofdir" ]; then
                add_node "dofinv_$id1-$i" -subfile "dofinv.sub"      \
                                          -var     "target=\"$id1\"" \
                                          -grpvar source -grpval ${srcids[@]}
                add_edge "dofinv_$id1-$i" "imgreg_$id1-$i"
                is_done='true'
                for id2 in ${srcids[@]}; do
                  if [ ! -f "$dofdir/$id2/$id1$dofsuf" ]; then
                    is_done='false'
                    break
                  fi
                done
                [[ $is_done == false ]] || node_done "dofinv_$id1-$i"
              fi
            fi
            let s1="$s2+1"
          done
        else
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
            [ ! -f "$dofdir/$id1/$id2$dofsuf" ] || node_done "imgreg_$id1,$id2"
            # node to invert inverse-consistent transformation
            if [[ $ic == true ]] && [ -n "$dofdir" ]; then
              add_node "dofinv_$id1,$id2" -subfile "dofinv.sub"      \
                                          -var     "target=\"$id1\"" \
                                          -var     "source=\"$id2\""
              add_edge "dofinv_$id1,$id2" "imgreg_$id1,$id2"
              [ ! -f "$dofdir/$id2/$id1$dofsuf" ] || node_done "dofinv_$id1,$id2"
            fi
            info "  Added job `printf '%3d of %d' $n $N`"
          done
        fi
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
# add node for inverting all transformations
dofinvert_node()
{
  local node=
  local parent=()
  local ids=()
  local dofins=
  local dofdir=
  local dofsuf='.dof.gz'

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids    "$@"; shift ${#ids[@]}; ;;
      -dofins)   optarg  dofins $1 "$2"; shift; ;;
      -dofdir)   optarg  dofdir $1 "$2"; shift; ;;
      -dofsuf)   optarg  dofsuf $1 "$2"; shift; ;;
      -*)        error "dofinvert_node: invalid option: $1"; ;;
      *)         [ -z "$node" ] || error "dofinvert_node: too many arguments"
                 node=$1; ;;
    esac
    shift
  done
  [ -n "$node"   ] || error "dofinvert_node: missing name argument"
  [ -n "$dofins" ] || error "dofinvert_node: missing -dofins argument"
  [ -n "$dofdir" ] || error "dofinvert_node: missing -dofdir argument"

  info "Adding node $node..."
  begin_dag $node -splice || {

    # create generic dofinvert submission script
    local sub="arguments = \"'$dofins/\$(id)$dofsuf' '$dofdir/\$(id)$dofsuf'\""
    sub="$sub\noutput    = $_dagdir/dofinv_\$(id).out"
    sub="$sub\nerror     = $_dagdir/dofinv_\$(id).out"
    sub="$sub\nqueue"
    make_sub_script "dofinv.sub" "$sub" -executable dofinvert

    # node to create output directories
    make_script "mkdirs.sh" "mkdir -p '$dofdir' || exit 1"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.out\nqueue"

    # add dofinvert nodes to DAG
    for id in "${ids[@]}"; do
      add_node "dofinv_$id" -subfile "dofinv.sub" -var "id=\"$id\""
      add_edge "dofinv_$id" 'mkdirs'
      [ ! -f "$dofdir/$id$dofsuf" ] || node_done "dofinv_$id"
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
      -parent)        optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects)      optargs ids    "$@"; shift ${#ids[@]}; ;;
      -doflst)        optarg  doflst $1 "$2"; shift; ;;
      -dofins)        optarg  dofins $1 "$2"; shift; ;;
      -dofdir)        optarg  dofdir $1 "$2"; shift; ;;
      -norigid)       options="$options -norigid";  ;;
      -notranslation) options="$options -notranslation";  ;;
      -norotation)    options="$options -norotation";  ;;
      -noscaling)     options="$options -noscaling";  ;;
      -noshearing)    options="$options -noshearing";  ;;
      -dofs)          options="$options -dofs"; ;;
      -*)             error "dofaverage_node: invalid option: $1"; ;;
      *)              [ -z "$node" ] || error "dofaverage_node: too many arguments"
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
  local dofid1=
  local dofid2=
  local dofid3=
  local dofdir1=
  local dofdir2=
  local dofdir3=
  local dofsuf='.dof.gz'
  local options=

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids    "$@"; shift ${#ids[@]}; ;;
      -dofid1)   optarg  dofid1  $1 "$2"; shift; ;;
      -dofid2)   optarg  dofid2  $1 "$2"; shift; ;;
      -dofid3)   optarg  dofid3  $1 "$2"; shift; ;;
      -dofdir1)  optarg  dofdir1 $1 "$2"; shift; ;;
      -dofdir2)  optarg  dofdir2 $1 "$2"; shift; ;;
      -dofdir3)  optarg  dofdir3 $1 "$2"; shift; ;;
      -dofsuf)   optarg  dofsuf  $1 "$2"; shift; ;;
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
  if [ -n "$dofid3" ]; then
    if [ -z "$dofid1" -o -z "$dofid2" ]; then
      error "dofcombine_node: -dofid3 requires fixed -dofid1 and -dofid2"
    fi
  else
    [ ${#ids[@]} -gt 0 ] || error "dofcombine_node: no -subjects specified"
  fi

  info "Adding node $node..."
  begin_dag $node -splice || {

    # create generic dofcombine submission script
    local sub="arguments = \""
    if [ -n "$dofid1" ]; then sub="$sub '$dofdir1/$dofid1$dofsuf'"
    else                      sub="$sub '$dofdir1/\$(id)$dofsuf'"; fi
    if [ -n "$dofid2" ]; then sub="$sub '$dofdir2/$dofid2$dofsuf'"
    else                      sub="$sub '$dofdir2/\$(id)$dofsuf'"; fi
    if [ -n "$dofid3" ]; then sub="$sub '$dofdir3/$dofid3$dofsuf'"
    else                      sub="$sub '$dofdir3/\$(id)$dofsuf'"; fi
    sub="$sub\""
    if [ -n "$dofid3" ]; then
      sub="$sub\noutput    = $_dagdir/dofcat_$dofid3.out"
      sub="$sub\nerror     = $_dagdir/dofcat_$dofid3.out"
    else
      sub="$sub\noutput    = $_dagdir/dofcat_\$(id).out"
      sub="$sub\nerror     = $_dagdir/dofcat_\$(id).out"
    fi
    sub="$sub\nqueue"
    make_sub_script "dofcat.sub" "$sub" -executable dofcombine

    # node to create output directories
    make_script "mkdirs.sh" "mkdir -p '$dofdir3' || exit 1"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.out\nqueue"

    # add dofcombine nodes to DAG
    if [ -n "$dofid3" ]; then
      add_node "dofcat_$dofid3" -subfile "dofcat.sub"
      add_edge "dofcat_$dofid3" 'mkdirs'
      [ ! -f "$dofdir3/$id.dof.gz" ] || node_done "dofcat_$id"
    else
      for id in "${ids[@]}"; do
        add_node "dofcat_$id" -subfile "dofcat.sub" -var "id=\"$id\""
        add_edge "dofcat_$id" 'mkdirs'
        [ ! -f "$dofdir3/$id.dof.gz" ] || node_done "dofcat_$id"
      done
    fi

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
  local options='-v'
  local label margin bgvalue

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids    "$@"; shift ${#ids[@]}; ;;
      -sublst)   optarg  idlst   $1 "$2"; shift; ;;
      -imgdir)   optarg  imgdir  $1 "$2"; shift; ;;
      -imgpre)   imgpre="$2"; shift; ;;
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
  [ -n "$average" ] || error "average_node: missing -output argument"
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
    local sub="arguments = \"$average -images '$imglst' $options\""
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
