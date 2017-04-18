################################################################################
# Workflow nodes for invocation of MIRTK commands
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
# add node for creation/approximation of (affine) transformations
init_dof_node()
{
  local node=
  local parent=()
  local ids=()
  local dofid=
  local dofins=
  local dofdir=
  local dofsuf='.dof.gz'
  local options=

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)        optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects)      optargs ids    "$@"; shift ${#ids[@]}; ;;
      -dofid)         optarg  dofid  $1 "$2"; shift; ;;
      -dofins)        optarg  dofins $1 "$2"; shift; ;;
      -dofdir)        optarg  dofdir $1 "$2"; shift; ;;
      -dofsuf)        optarg  dofsuf $1 "$2"; shift; ;;
      -notranslation) options="$options -notranslations";  ;;
      -norotation)    options="$options -norotations"; ;;
      -noscaling)     options="$options -noscaling"; ;;
      -noshearing)    options="$options -noshearing"; ;;
      -*)             error "init_dofs_node: invalid option: $1"; ;;
      *)              [ -z "$node" ] || error "init_dofs_node: too many arguments"
                      node=$1; ;;
    esac
    shift
  done
  [ -n "$node"   ] || error "init_dofs_node: missing name argument"
  [ -n "$dofins" ] || error "init_dofs_node: missing -dofins argument"
  [ -n "$dofdir" ] || error "init_dofs_node: missing -dofdir argument"
  [ -n "$dofid" ] || [ ${#ids[@]} -gt 0 ] || {
    error "init_dofs_node: no -subjects or -dofid specified"
  }

  info "Adding node $node..."
  begin_dag $node -splice || {

    # create generic dofinit submission script
    local sub="arguments = \""
    if [ -n "$dofid" ]; then sub="$sub '$dofdir/$dofid$dofsuf'"
    else                     sub="$sub '$dofdir/\$(id)$dofsuf'"; fi
    if [ -n "$dofid" ]; then sub="$sub -approximate '$dofins/$dofid$dofsuf'"
    else                     sub="$sub -approximate '$dofins/\$(id)$dofsuf'"; fi
    sub="$sub $options -threads $threads\""
    if [ -n "$dofid" ]; then
      sub="$sub\noutput    = $_dagdir/dofini_$dofid.log"
      sub="$sub\nerror     = $_dagdir/dofini_$dofid.log"
    else
      sub="$sub\noutput    = $_dagdir/dofini_\$(id).log"
      sub="$sub\nerror     = $_dagdir/dofini_\$(id).log"
    fi
    sub="$sub\nqueue"
    make_sub_script "dofini.sub" "$sub" -executable init-dof

    # node to create output directories
    local deps=()
    if [[ $dofdir != '.' ]]; then
      make_script "mkdirs.sh" "mkdir -p '$dofdir' || exit 1"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
      [ ! -d "$dofdir" ] || node_done "mkdirs"
      deps=('mkdirs')
    fi

    # add dofcreate nodes to DAG
    if [ -n "$dofid" ]; then
      add_node "dofini_$dofid" -subfile "dofini.sub"
      for dep in ${deps[@]}; do
        add_edge "dofini_$dofid" "$dep"
      done
      [ ! -f "$dofdir/$dofid$dofsuf" ] || node_done "dofini_$dofid"
    else
      for id in "${ids[@]}"; do
        add_node "dofini_$id" -subfile "dofini.sub" -var "id=\"$id\""
        for dep in ${deps[@]}; do
          add_edge "dofini_$id" "$dep"
        done
        [ ! -f "$dofdir/$id$dofsuf" ] || node_done "dofini_$id"
      done
    fi

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}

# ------------------------------------------------------------------------------
# add node for pairwise image registration
register_node()
{
  local args w i j t s lvl res blr is_done segment

  local node=
  local parent=()
  local tgtdir=
  local tgtid=
  local tgtpre='$imgpre'
  local tgtsuf='$imgsuf'
  local srcdir=
  local srcid=
  local srcpre='$imgpre'
  local srcsuf='$imgsuf'
  local pairs=
  local ids=()
  local idlst=
  local imgdir=
  local imgpre=
  local imgsuf='.nii.gz'
  local domain=
  local model=
  local mffd='Sum'
  local similarity='NMI'
  local bins=64
  local radius=2
  local interp='Fast linear'
  local resolution=
  local levels=(4 1)
  local hdrdofs=
  local hdrdof_opt='-dof'
  local dofins=
  local dofdir=
  local dofid=
  local dofsuf='.dof.gz'
  local bgvalue=
  local inclbg=false
  local segdir=
  local segments=()
  local ic='false'
  local sym='false'
  local group=1
  local invgrp=0
  local params=
  local maxstep=0

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)
        optargs parent "$@"
        shift ${#parent[@]}; ;;
      -tgtid|-refid)
        tgtid="$2"
        shift; ;;
      -srcid)
        srcid="$2"
        shift; ;;
      -tgtdir|-refdir)
        tgtdir="$2"
        shift; ;;
      -srcdir)
        srcdir="$2"
        shift; ;;
      -tgtpre|-refpre)
        tgtpre="$2"
        shift; ;;
      -srcpre)
        srcpre="$2"
        shift; ;;
      -imgpre)
        imgpre="$2"
        shift; ;;
      -tgtsuf|-refsuf)
        tgtsuf="$2"
        shift; ;;
      -srcsuf)
        srcsuf="$2"
        shift; ;;
      -imgsuf)
        optarg imgsuf $1 "$2"
        shift; ;;
      -imgdir)
        optarg imgdir $1 "$2"
        shift; ;;
      -domain)
        optarg domain $1 "$2"
        shift; ;;
      -subjects|-ids)
        unset -v ids
        optargs ids "$@"
        shift ${#ids[@]}; ;;
      -sublst|-idlst)
        optarg idlst $1 "$2"
        shift; ;;
      -pairs)
        optarg pairs $1 "$2"
        shift; ;;
      -model)
        optarg model $1 "$2"
        shift; ;;
      -mffd)
        optarg mffd $1 "$2"
        shift; ;;
      -hdrdofs)
        hdrdofs="$2"
        shift; hdrdof_opt='-dof'; ;;
      -invhdrdofs)
        hdrdofs="$2"
        shift; hdrdof_opt='-dof_i'; ;;
      -dofins)
        optarg dofins $1 "$2"
        shift; ;;
      -dofdir)
        optarg dofdir $1 "$2"
        shift; ;;
      -dofid)
        optarg dofid $1 "$2"
        shift; ;;
      -dofsuf)
        optarg dofsuf $1 "$2"
        shift; ;;
      -segdir)
        optarg segdir $1 "$2"
        shift; ;;
      -segmsk)
        unset -v segment
        optargs segment "$@"
        if [ ${#segment[@]} -gt 2 ]; then
          error "register_node: too many arguments for option: $1"
        fi
        shift ${#segment[@]}
        if [ ${#segment[@]} -eq 1 ]; then
          segment=("${segment[0]}" 1)
        fi
        segments=("${segments[@]}" "${segment[@]}"); ;;
      -par)
        optargs args "$@"
        if [ ${#args[@]} -ne 2 ]; then
          error "register_node: option requires two arguments: $1"
        fi
        shift 2
        params="$params\n${args[0]} = ${args[1]}"; ;;
      -sim|-similarity)
        optarg similarity $1 "$2"
        shift; ;;
      -bins)
        optarg bins $1 "$2"
        shift; ;;
      -radius)
        optarg radius $1 "$2"
        shift; ;;
      -bgvalue)
        optarg bgvalue $1 "$2"
        shift; ;;
      -inclbg)
        optarg inclbg $1 "$2"
        shift; ;;
      -interp)
        optarg interp $1 "$2"
        shift; ;;
      -maxres)
        optarg resolution $1 "$2"
        shift; ;;
      -maxstep)
        optarg maxstep $1 "$2"
        shift; ;;
      -levels)
        unset -v levels
        optargs levels "$@"
        if [ ${#levels[@]} -gt 2 ]; then
          error "register_node: too many arguments for option: $1"
        fi
        shift ${#levels[@]}
        if [ ${#levels[@]} -eq 1 ]; then
          levels=("${levels[0]}" 1)
        fi; ;;
      -inverse-consistent)
        if [[ $2 == true ]]; then
          ic='true'; shift
        elif [[ $2 == false ]]; then
          ic='false'; shift
        else
          ic='true'
        fi
        ;;
      -symmetric)
        if [[ $2 == true ]]; then
          sym='true'; shift
        elif [[ $2 == false ]]; then
          sym='false'; shift
        else
          sym='true'
        fi
        [[ $sym == false ]] || ic='true'
        ;;
      -exclude-constraints)
        params="$params\nExclude constraints from energy value = Yes"
        ;;
      -ds|-spacing)
        optarg w $1 "$2"
        params="$params\nControl point spacing = $w"
        shift; ;;
      -be|-bending)
        optarg w $1 "$2"
        params="$params\nBending energy weight = $w"
        shift; ;;
      -vp|-volume)
        optarg w $1 "$2"
        params="$params\nVolume preservation weight = $w"
        shift; ;;
      -jl|-jac|-jacobian)
        optarg w $1 "$2"
        params="$params\nJacobian penalty weight = $w"
        shift; ;;
      -group)
        optarg group $1 "$2"
        shift; ;;
      -group-inv)
        optarg invgrp $1 "$2"
        shift; ;;
      -*)
        error "register_node: invalid option: $1"; ;;
      *)
        [ -z "$node" ] || error "register_node: too many arguments"
        node="$1"; ;;
    esac
    shift
  done
  [ -n "$node" ] || error "register_node: missing name argument"
  [ -n "$model" ] || error "register_node: missing -model argument"
  if [ -n "$idlst" ]; then
    [ ${#ids[@]} -eq 0 ] || error "register_node: options -subjects and -sublst are mutually exclusive"
    read_sublst ids "$idlst"
  fi
  [ ${#ids[@]} -ge 2 ] || [ ${#ids[@]} -gt 0 -a -n "$tgtid$srcid" ] || [ -n "$tgtid" -a -n "$srcid" ] || {
    error "register_node: not enough -subjects specified"
  }
  if [ -n "$tgtid" -a -n "$srcid" ]; then
    [ ${#ids[@]} -eq 0 ] || {
      error "register_node: option -subjects / -sublst cannot be used when both -tgtid and -srcid given"
    }
  fi
  if [[ $dofins == 'identity' ]] || [[ $dofins == 'id' ]]; then
    dofins='Id'
  fi
  [ -n "$dofdir" ] || error "register_node: missing output -dofdir argument"
  [ -n "$tgtdir" ] || tgtdir="$imgdir"
  [ -n "$srcdir" ] || srcdir="$imgdir"
  [[ $tgtpre != '$imgpre' ]] || tgtpre="$imgpre"
  [[ $tgtsuf != '$imgsuf' ]] || tgtsuf="$imgsuf"
  [[ $srcpre != '$imgpre' ]] || srcpre="$imgpre"
  [[ $srcsuf != '$imgsuf' ]] || srcsuf="$imgsuf"
  if [ -n "$dofid" ]; then
    if [ -z "$tgtid" -o -z "$srcid" ]; then
      error "register_node: -dofid requires a fixed -tgtid and -srcid"
    fi
  else
    if [ -n "$tgtid" -a -n "$srcid" ]; then
      dofid="$tgtid/$srcid"
    fi
  fi
  if [ ${levels[0]} -lt ${levels[1]} ]; then
    error "register_node: invalid -levels arguments, first level must be greater than final level"
  fi
  if [ ${#segments[@]} -ne 0 -a -z "$segdir" ]; then
    error "register_node: -mskdir option required when -segmsk used"
  fi
  if [ -n "$pairs" ] && [ -z "$tgtid$srcid" ] && [ ! -f "$pairs" ]; then
    error "register_node: specified -pairs file does not exist: $pairs"
  fi
  [ $invgrp -gt 0 ] || invgrp=$group

  local nlevels=${levels[0]}
  if [ -n "$resolution" ]; then
    let nlevels="${levels[0]} - ${levels[1]} + 1"
    resolution=$('/usr/bin/bc' -l <<< "2^(${levels[1]}-1) * $resolution")
    resolution=$(remove_trailing_zeros $resolution)
    levels=($nlevels 1)
  fi

  local fidelity
  local register_tool="register"
  if [[ $model == 'Rigid' ]] || [[ $model == 'Similarity' ]] || [[ $model == 'Affine' ]]; then
    fidelity='SIM[Image similarity](I(1), I(2) o T)'
    if [[ $ic == true ]]; then
      register_tool="register-affine-ic"
    fi
  else
    if [[ $sym == true ]]; then
      fidelity='SIM[Image similarity](I(1) o T^-.5, I(2) o T^.5)'
    elif [[ $ic == true ]]; then
      fidelity='SIM[Fwd image similarity](I(1), I(2) o T) + SIM[Bwd image similarity](I(1) o T^-1, I(2))'
    else
      fidelity='SIM[Image similarity](I(1), I(2) o T)'
    fi
  fi
  i=0
  while [ $i -lt ${#segments[@]} ]; do
    let j="$i + 1"
    let t="$i + 3"
    let s="$i + 4"
    if [[ $register_tool == 'register' ]]; then
      if [[ $sym == true ]]; then
        fidelity="$fidelity + ${segments[j]} SSD[${segments[i]} difference](I($t) o T^-.5, I($s) o T^.5)"
      elif [[ $ic == true ]]; then
        fidelity="$fidelity + ${segments[j]} SSD[Fwd ${segments[i]} difference](I($t), I($s) o T)"
        fidelity="$fidelity + ${segments[j]} SSD[Bwd ${segments[i]} difference](I($t) o T^-1, I($s))"
      else
        fidelity="$fidelity + ${segments[j]} SSD[${segments[i]} difference](I($t), I($s) o T)"
      fi
    else
      fidelity="$fidelity + ${segments[j]} SSD[${segments[i]} difference](I($t), I($s) o T)"
    fi
    let i="$i + 2"
  done

  # number of registrations
  local N
  if [ -n "$dofid" ]; then
    N=1
  elif [ -n "$tgtid" -o -n "$srcid" ]; then
    N=${#ids[@]}
  elif [ -n "$pairs" ]; then
    N=($(wc -l "$pairs"))
    [ $? -eq 0 ] || error "Failed to determine number of unique image pairs!"
    N=${N[0]}
    [ $N -gt 0 ] || error "Invalid number of unique image pairs!"
    [[ $ic == true ]] || let N="$N * 2"
  else
    let N="${#ids[@]} * (${#ids[@]} - 1)"
    [[ $ic == false ]] || let N="$N / 2"
  fi

  # add SUBDAG node
  info "Adding node $node (N=$N)..."
  begin_dag $node -splice || {

    # registration parameters
    local cfg="[default]"
    cfg="$cfg\nTransformation model             = $model"
    cfg="$cfg\nMulti-level transformation       = $mffd"
    cfg="$cfg\nImage interpolation mode         = $interp"
    cfg="$cfg\nEnergy function                  = $fidelity + 0 BE[Bending energy](T) + 0 VP[Volume preservation](T) + 0 JAC[Jacobian penalty](T)"
    cfg="$cfg\nSimilarity measure               = $similarity"
    cfg="$cfg\nNo. of bins                      = $bins"
    cfg="$cfg\nLocal window radius [box]        = $radius vox"
    cfg="$cfg\nNo. of last function values      = 10"
    cfg="$cfg\nNo. of resolution levels         = $nlevels"
    cfg="$cfg\nFinal resolution level           = ${levels[1]}"
    if [ -n "$bgvalue" ]; then
      cfg="$cfg\nBackground value of image 1      = $bgvalue"
      cfg="$cfg\nBackground value of image 2      = $bgvalue"
    fi
    if [[ $inclbg == true ]]; then
      cfg="$cfg\nDownsample images with padding   = No"
      cfg="$cfg\nImage similarity foreground      = Mask"
    else
      cfg="$cfg\nDownsample images with padding   = Yes"
      cfg="$cfg\nImage similarity foreground      = Overlap"
    fi
    if [ $maxstep -gt 0 ]; then
      cfg="$cfg\nMaximum length of steps          = $maxstep"
      cfg="$cfg\nStrict total step length range   = Yes"
    fi
    cfg="$cfg\nStrict step length range         = No"
    cfg="$cfg\nMaximum streak of rejected steps = 2"
    cfg="$cfg\n$params\n"
    if [ -n "$resolution" ]; then
      cfg="$cfg\n"
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
      lvl=1
      while [ $lvl -le ${levels[0]} ]; do
        cfg="$cfg\n\n[level $lvl]"
        i=0
        while [ $i -lt ${#segments[@]} ]; do
          let j="$i + 3"
          cfg="$cfg\nBlurring of image $j = 2 vox"
          let i++
        done
        let lvl++
      done
    fi
    if [ $maxstep -gt 0 ]; then
      if [[ $model == Rigid ]] || [[ $model == Similarity ]] || [[ $model == Affine ]]; then
        cfg="$cfg\n"
        lvl=1
        while [ $lvl -le ${levels[0]} ]; do
          cfg="$cfg\n\n[level $lvl]"
          cfg="$cfg\nMaximum length of steps = $maxstep"
          let lvl++
        done
      fi
    fi
    parin="$_dagdir/imgreg.cfg"
    write "$parin" "$cfg\n"

    # create generic register command script
    local sub="arguments    = \"-model '$model' -threads $threads"
    [ -z "$domain" ] || sub="$sub -mask '$domain'"
    sub="$sub -parin '$parin'"
    if [ -n "$tgtid" -a -n "$srcid" ]; then
      sub="$sub -parout '$_dagdir/reg_$tgtid,$srcid.cfg'"
      sub="$sub -image '$tgtdir/$tgtpre$tgtid$tgtsuf'"
      [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/$tgtid$dofsuf'"
      sub="$sub -image '$srcdir/$srcpre$srcid$srcsuf'"
      [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/$srcid$dofsuf'"
      i=0
      while [ $i -lt ${#segments[@]} ]; do
        sub="$sub -image '$segdir/${segments[i]}/$segpre$tgtid$segsuf'"
        [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/$tgtid$dofsuf'"
        sub="$sub -image '$segdir/${segments[i]}/$segpre$srcid$segsuf'"
        [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/$srcid$dofsuf'"
        let i="$i + 2"
      done
      if [[ "$dofins" == 'Id' ]]; then
        sub="$sub -dofin Id"
      elif [ -n "$dofins" ]; then
        sub="$sub -dofin '$dofins/$dofid$dofsuf'"
      fi
      sub="$sub -dofout '$dofdir/$dofid$dofsuf'"
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/reg_$tgtid,$srcid.log"
      sub="$sub\nerror        = $_dagdir/reg_$tgtid,$srcid.log"
    elif [ -n "$tgtid" ]; then
      sub="$sub -parout '$_dagdir/reg_\$(source).cfg'"
      sub="$sub -image '$tgtdir/$tgtpre$tgtid$tgtsuf'"
      sub="$sub -image '$imgdir/$imgpre\$(source)$imgsuf'"
      [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(source)$dofsuf'"
      i=0
      while [ $i -lt ${#segments[@]} ]; do
        if [ -f "$tgtdir/$tgtpre$tgtid-${segments[i]}$segsuf" ]; then
          sub="$sub -image '$tgtdir/$tgtpre$tgtid-${segments[i]}$segsuf'"
        else
          sub="$sub -image '$segdir/${segments[i]}/$segpre$tgtid$segsuf'"
        fi
        [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/$tgtid$dofsuf'"
        sub="$sub -image '$segdir/${segments[i]}/$segpre\$(source)$segsuf'"
        [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(source)$dofsuf'"
        let i="$i + 2"
      done
      if [[ "$dofins" == 'Id' ]]; then
        sub="$sub -dofin Id"
      elif [ -n "$dofins" ]; then
        sub="$sub -dofin '$dofins/\$(source)$dofsuf'"
      fi
      sub="$sub -dofout '$dofdir/\$(source)$dofsuf'"
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/reg_\$(source).log"
      sub="$sub\nerror        = $_dagdir/reg_\$(source).log"
    elif [ -n "$srcid" ]; then
      sub="$sub -parout '$_dagdir/reg_\$(target).cfg'"
      sub="$sub -image '$imgdir/$imgpre\$(target)$imgsuf'"
      [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(target)$dofsuf'"
      sub="$sub -image '$srcdir/$srcpre$srcid$srcsuf'"
      i=0
      while [ $i -lt ${#segments[@]} ]; do
        sub="$sub -image '$segdir/${segments[i]}/$segpre\$(target)$segsuf'"
        [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(target)$dofsuf'"
        if [ -f "$srcdir/$srcpre$srcid-${segments[i]}$segsuf" ]; then
          sub="$sub -image '$srcdir/$srcpre$srcid-${segments[i]}$segsuf'"
        else
          sub="$sub -image '$segdir/${segments[i]}/$segpre$srcid$segsuf'"
        fi
        [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/$srcid$dofsuf'"
        let i="$i + 2"
      done
      if [[ "$dofins" == 'Id' ]]; then
        sub="$sub -dofin Id"
      elif [ -n "$dofins" ]; then
        sub="$sub -dofin '$dofins/\$(target)$dofsuf'"
      fi
      sub="$sub -dofout '$dofdir/\$(target)$dofsuf'"
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/reg_\$(target).log"
      sub="$sub\nerror        = $_dagdir/reg_\$(target).log"
    else
      sub="$sub -parout '$_dagdir/\$(target)/reg_\$(source).cfg'"
      sub="$sub -image '$imgdir/$imgpre\$(target)$imgsuf'"
      [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(target)$dofsuf'"
      sub="$sub -image '$imgdir/$imgpre\$(source)$imgsuf'"
      [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(source)$dofsuf'"
      i=0
      while [ $i -lt ${#segments[@]} ]; do
        sub="$sub -image '$segdir/${segments[i]}/$segpre\$(target)$segsuf'"
        [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(target)$dofsuf'"
        sub="$sub -image '$segdir/${segments[i]}/$segpre\$(source)$segsuf'"
        [ -z "$hdrdofs" ] || sub="$sub $hdrdof_opt '$hdrdofs/\$(source)$dofsuf'"
        let i="$i + 2"
      done
      if [[ "$dofins" == 'Id' ]]; then
        sub="$sub -dofin Id"
      elif [ -n "$dofins" ]; then
        sub="$sub -dofin '$dofins/\$(target)/\$(source)$dofsuf'"
      fi
      sub="$sub -dofout '$dofdir/\$(target)/\$(source)$dofsuf'"
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/\$(target)/reg_\$(source).log"
      sub="$sub\nerror        = $_dagdir/\$(target)/reg_\$(source).log"
    fi
    sub="$sub\nqueue"
    make_sub_script "register.sub" "$sub" -executable "$register_tool"

    # create generic dofinvert submission script
    if [[ $ic == true ]] && [ -z "$tgtid$srcid" ] ; then
      # command used to invert inverse-consistent transformation
      local sub="arguments    = \"'$dofdir/\$(target)/\$(source)$dofsuf' '$dofdir/\$(source)/\$(target)$dofsuf'\""
      sub="$sub\noutput       = $_dagdir/\$(target)/inv_\$(source).log"
      sub="$sub\nerror        = $_dagdir/\$(target)/inv_\$(source).log"
      sub="$sub\nqueue"
      make_sub_script "invert.sub" "$sub" -executable invert-dof
    fi

    # job to create output directories
    # better to have it done by a single script for all directories
    # than a PRE script for each registration job, which would require
    # the -maxpre option to avoid memory issues
    local pre=
    is_done=true
    if [ -n "$tgtid" -o -n "$srcid" ]; then
      # directory for output files
      pre="$pre\nmkdir -p '$dofdir' || exit 1"
      [ -d "$dofdir" ] || is_done=false
    else
      # directory for log files
      for id in "${ids[@]}"; do
        pre="$pre\nmkdir -p '$_dagdir/$id' || exit 1"
      done
      for id in "${ids[@]}"; do
        if [ ! -d "$_dagdir/$id" ]; then
          is_done=false
          break
        fi
      done
      # directory for output files
      pre="$pre\n"
      for id in "${ids[@]}"; do
        pre="$pre\nmkdir -p '$dofdir/$id' || exit 1"
      done
      if [[ is_done == true ]]; then
        for id in "${ids[@]}"; do
          if [ ! -d "$dofdir/$id" ]; then
            is_done=false
            break
          fi
        done
      fi
    fi
    if [ -n "$pre" ]; then
      make_script "mkdirs.sh" "$pre"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
      [[ is_done == false ]] || node_done "mkdirs"
    fi

    # add node to register target to source
    if [ -n "$tgtid" -a -n "$srcid" ]; then
      add_node "reg_$tgtid,$srcid" -subfile "register.sub"
      [ -z "$pre" ] || add_edge "reg_$tgtid,$srcid" 'mkdirs'
      [ ! -f "$dofdir/$dofid$dofsuf" ] || node_done "reg_$tgtid,$srcid"
    # add nodes to register subject images to common reference
    elif [ -n "$tgtid" ]; then
      if [ $group -gt 1 ]; then
        i=1
        while [ $i -le ${#ids[@]} ]; do
          srcids=("${ids[@]:$i-1:$group}")
          let j="$i + ${#srcids[@]} - 1"
          add_node "reg_$i-$j" -subfile "register.sub" -grpvar 'source' -grpval "${srcids[@]}"
          [ -z "$pre" ] || add_edge "reg_$i-$j" 'mkdirs'
          is_done='true'
          for id in ${ids[@]:$i:$group}; do
            if [ ! -f "$dofdir/$id$dofsuf" ]; then
              is_done='false'
              break
            fi
          done
          [[ $is_done == false ]] || node_done "reg_$i-$j"
          let i="$j + 1"
        done
      else
        for id in "${ids[@]}"; do
          add_node "reg_$id" -subfile "register.sub" -var "source=\"$id\""
          [ -z "$pre" ] || add_edge "reg_$id" 'mkdirs'
          [ ! -f "$dofdir/$id$dofsuf" ] || node_done "reg_$id"
        done
      fi
    # add nodes to register common reference to subject images
    elif [ -n "$srcid" ]; then
      if [ $group -gt 1 ]; then
        i=1
        while [ $i -le ${#ids[@]} ]; do
          srcids=("${ids[@]:$i-1:$group}")
          let j="$i + ${#srcids[@]} - 1"
          add_node "reg_$i-$j" -subfile "register.sub" -grpvar 'target' -grpval "${srcids[@]}"
          [ -z "$pre" ] || add_edge "reg_$i-$j" 'mkdirs'
          is_done='true'
          for id in ${ids[@]:$i:$group}; do
            if [ ! -f "$dofdir/$id$dofsuf" ]; then
              is_done='false'
              break
            fi
          done
          [[ $is_done == false ]] || node_done "reg_$i-$j"
          let i="$j + 1"
        done
      else
        for id in "${ids[@]}"; do
          add_node "reg_$id" -subfile "register.sub" -var "target=\"$id\""
          [ -z "$pre" ] || add_edge "reg_$id" 'mkdirs'
          [ ! -f "$dofdir/$id$dofsuf" ] || node_done "reg_$id"
        done
      fi
    # register all pairs of images
    else
      t=0
      local s1 s2 S grpids srcids id1 id2
      for id1 in "${ids[@]}"; do
        let t++
        # register all other images to image with id1
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
              while [ $s -le $s2 ] && [ $s -le ${#ids[@]} ]; do
                [ $s -ge $t ] || {
                  id2="${ids[$s-1]}"
                  if [ -z "$pairs" ] || [ $(egrep "^($id1,$id2|$id2,$id1)$" "$pairs" | wc -l) -ne 0 ]; then
                    srcids=("${srcids[@]}" "$id2")
                  fi
                }
                let s++
              done
            else
              while [ $s -le $s2 ] && [ $s -le ${#ids[@]} ]; do
                [ $s -eq $t ] || {
                  id2="${ids[$s-1]}"
                  if [ -z "$pairs" ] || [ $(egrep "^($id1,$id2|$id2,$id1)$" "$pairs" | wc -l) -ne 0 ]; then
                    srcids=("${srcids[@]}" "$id2")
                  fi
                }
                let s++
              done
            fi
            if [ ${#srcids[@]} -gt 0 ]; then
              let i++
              let j="$i + ${#srcids[@]} - 1"
              # node of n grouped jobs to register source images to image with id1
              add_node "reg_$id1,$i-$j" -subfile "register.sub" \
                                        -var     "target=\"$id1\"" \
                                        -grpvar  "source" \
                                        -grpval  "${srcids[@]}"
              add_edge "reg_$id1,$i-$j" 'mkdirs'
              is_done='true'
              for id2 in ${srcids[@]}; do
                if [ ! -f "$dofdir/$id1/$id2$dofsuf" ]; then
                  is_done='false'
                  break
                fi
              done
              [[ $is_done == false ]] || node_done "reg_$id1,$i-$j"
              # node of n grouped jobs to invert inverse-consistent transformations
              if [[ $ic == true ]] && [ -n "$dofdir" ]; then
                add_node "inv_$id1,$i-$j" -subfile "invert.sub" \
                                          -var     "target=\"$id1\"" \
                                          -grpvar  "source" \
                                          -grpval  "${srcids[@]}"
                add_edge "inv_$id1,$i-$j" "reg_$id1,$i-$j"
                is_done='true'
                for id2 in ${srcids[@]}; do
                  if [ ! -f "$dofdir/$id2/$id1$dofsuf" ]; then
                    is_done='false'
                    break
                  fi
                done
                [[ $is_done == false ]] || node_done "inv_$id1,$i-$j"
              fi
            fi
            let s1="$s2 + 1"
          done
        else
          # add nodes of individual jobs to register id1 and id2
          s=0
          local id2s=()
          for id2 in "${ids[@]}"; do
            let s++
            if [[ $ic == true ]]; then
              [ $t -lt $s ] || continue
            else
              [ $t -ne $s ] || continue
            fi
            if [ -n "$pairs" ] && [ $(egrep "^($id1,$id2|$id2,$id1)$" "$pairs" | wc -l) -eq 0 ]; then
              continue
            fi
            add_node "reg_$id1,$id2" -subfile "register.sub" \
                                     -var     "target=\"$id1\"" \
                                     -var     "source=\"$id2\""
            add_edge "reg_$id1,$id2" 'mkdirs'
            [ ! -f "$dofdir/$id1/$id2$dofsuf" ] || node_done "reg_$id1,$id2"
            id2s=("${id2s[@]}" "$id2")
          done
          # add nodes of jobs to invert inverse-consistent transformations
          if [[ $ic == true ]] && [ -n "$dofdir" ]; then
            if [ $invgrp -gt 1 ]; then
              i=1
              while [ $i -le ${#id2s[@]} ]; do
                srcids=("${id2s[@]:$i-1:$invgrp}")
                let j="$i + ${#srcids[@]} - 1"
                add_node "inv_$id1,$i-$j" -subfile "invert.sub" \
                                          -var     "target=\"$id1\"" \
                                          -grpvar  "source" \
                                          -grpval  "${srcids[@]}"
                for id2 in ${srcids[@]}; do
                  add_edge "inv_$id1,$i-$j" "reg_$id1,$id2"
                done
                is_done=true
                for id2 in ${srcids[@]}; do
                  if [ ! -f "$dofdir/$id2/$id1$dofsuf" ]; then
                    is_done=false
                    break
                  fi
                done
                [[ $is_done == false ]] || node_done "inv_$id1,$i-$j"
                let i="$j + 1"
              done
            else
              for id2 in "${id2s[@]}"; do
                add_node "inv_$id1,$id2" -subfile "invert.sub" \
                                         -var     "target=\"$id1\"" \
                                         -var     "source=\"$id2\""
                add_edge "inv_$id1,$id2" "reg_$id1,$id2"
                [ ! -f "$dofdir/$id2/$id1$dofsuf" ] || node_done "inv_$id1,$id2"
              done
            fi
          fi
        fi
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
  local id1 id2

  local node=
  local parent=()
  local ids=()
  local imgdir=
  local imgpre=
  local imgsuf='.nii.gz'
  local srcid=
  local srcdir=
  local srcpre='$imgpre'
  local srcsuf='$imgsuf'
  local tgtid=
  local tgtdir=
  local tgtpre='$imgpre'
  local tgtsuf='$imgsuf'
  local outdir=
  local outid=
  local outpre='$srcpre'
  local outsuf='$srcsuf'
  local ref=
  local refid=
  local refdir=
  local refpre=
  local refsuf='.nii.gz'
  local hdrdofs=
  local dofin1=
  local dofin2=
  local dofin3=
  local inv1='false'
  local inv2='false'
  local inv3='false'
  local dofid1='$(source)'
  local dofid2='$(source)'
  local dofid3='$(source)'
  local dofpre=
  local dofsuf='.dof.gz'
  local padding=0
  local interp='linear'
  local resample='false'
  local invert='false'
  local spacing=()
  local labels=()

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)             optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects)           optargs ids    "$@"; shift ${#ids[@]}; ;;
      -imgdir)             optarg  imgdir $1 "$2"; shift; ;;
      -imgpre)             imgpre="$2"; shift; ;;
      -imgsuf)             imgsuf="$2"; shift; ;;
      -tgtdir)             optarg tgtdir $1 "$2"; shift; ;;
      -tgtid)              tgtid="$2";  shift; ;;
      -tgtpre)             tgtpre="$2"; shift; ;;
      -tgtsuf)             tgtsuf="$2"; shift; ;;
      -srcdir)             optarg  srcdir $1 "$2"; shift; ;;
      -srcid)              srcid="$2"; shift; ;;
      -srcpre)             srcpre="$2"; shift; ;;
      -srcsuf)             srcsuf="$2"; shift; ;;
      -outdir)             optarg  outdir $1 "$2"; shift; ;;
      -ref)                optarg  ref    $1 "$2"; shift; ;;
      -refdir)             optarg  refdir $1 "$2"; shift; ;;
      -refid)              refid="$2";  shift; ;;
      -refpre)             refpre="$2"; shift; ;;
      -refsuf)             refsuf="$2"; shift; ;;
      -outid)              outid="$2"; shift; ;;
      -outpre)             outpre="$2"; shift; ;;
      -outsuf)             outsuf="$2"; shift; ;;
      -hdrdofs)            optarg hdrdofs $1 "$2"; shift; ;;
      -dofins|-dofin1) dofin1=(); optarg dofin1  $1 "$2"; shift; ;;
      -dofin2) dofin2=(); optarg dofin2 $1 "$2"; shift; ;;
      -dofin3) dofin3=(); optarg dofin3 $1 "$2"; shift; ;;
      -dofid1) optarg dofid1 $1 "$2"; shift; ;;
      -dofid2) optarg dofid2 $1 "$2"; shift; ;;
      -dofid3) optarg dofid3 $1 "$2"; shift; ;;
      -dofinv1) inv1='true'; ;;
      -dofinv2) inv2='true'; ;;
      -dofinv3) inv3='true'; ;;
      -dofsuf)             optarg dofsuf  $1 "$2"; shift; ;;
      -bgvalue|-padding)   optarg padding $1 "$2"; shift; ;;
      -interp)             optarg interp  $1 "$2"; shift; ;;
      -labels)
        labels=()
        optargs labels "$@"
        shift ${#labels[@]}; ;;
      -dofinv|-invert) invert='true'; ;;
      -include_identity)   resample='true'; ;;
      -spacing|-voxelsize|-resolution)
        spacing=()
        optargs spacing "$@"
        if [ ${#spacing[@]} -gt 3 ]; then
          error "transform_image_node: too many -spacing, -voxelsize, -resolution arguments"
        fi
        shift ${#spacing[@]}
        ;;
      -*)                  error "transform_image_node: invalid option: $1"; ;;
      *)                   [ -z "$node" ] || error "transform_image_node: too many arguments"
                           node=$1; ;;
    esac
    shift
  done
  [ -n "$node"   ] || error "transform_image_node: missing name argument"
  [ -n "$outdir" ] || error "transform_image_node: missing -outdir argument"
  if [ -n "$srcid" ]; then
    [ ${#ids[@]} -eq 0 ] || error "transform_image_node: options -srcid and -subjects are mutually exclusive"
  else
    [ ${#ids[@]} -ge 2 ] || error "transform_image_node: not enough -subjects specified"
  fi
  [ -n "$tgtdir" ] || tgtdir="$imgdir"
  [ -n "$srcdir" ] || srcdir="$imgdir"
  [[ $tgtpre != '$imgpre' ]] || tgtpre="$imgpre"
  [[ $tgtsuf != '$imgsuf' ]] || tgtsuf="$imgsuf"
  [[ $srcpre != '$imgpre' ]] || srcpre="$imgpre"
  [[ $srcsuf != '$imgsuf' ]] || srcsuf="$imgsuf"
  [[ $outpre != '$srcpre' ]] || outpre="$srcpre"
  [[ $outsuf != '$srcsuf' ]] || outsuf="$srcsuf"
  if [ -z "$ref" -a -n "$refid" ]; then
    ref="$refdir/$refpre$refid$refsuf"
  fi
  if [ -n "$outid" ]; then
    [ -n "$srcid" -a -n "$tgtid" ] || {
      error "transform_image_node: option -outid only valid when a single -tgtid and -srcid is specified"
    }
  else
    outid='$(source)'
  fi

  # number of transform-image jobs
  local N=1
  if [ -n "$tgtid" -a -n "$srcid" ]; then
    N=1
  elif [ -n "$tgtid$srcid" ]; then
    N=${#ids[@]}
    if [[ $resample != true ]]; then
      id2="$tgtid"
      [ -n "$id2" ] || id2="$srcid"
      for id1 in ${ids[@]}; do
        if [[ "$id1" == "$id2" ]]; then
          let N--
        fi
      done
    fi
  elif [[ $resample == true ]]; then
    let N="${#ids[@]} * ${#ids[@]}"
  else
    let N="${#ids[@]} * (${#ids[@]} - 1)"
  fi
  local subdir=
  if [ -z "$tgtid" ]; then
    subdir="\$(target)/"
  fi

  # add SUBDAG node
  info "Adding node $node..."
  begin_dag $node -splice || {

    local sub

    # source transformations
    local dofins=()
    local dofinv=()
    if [ -n "$dofin1" ]; then
      dofins=("${dofins[@]}" "$dofin1/$subdir$dofid1$dofsuf")
      dofinv=(${dofinv[@]} $inv1)
    fi
    if [ -n "$dofin2" ]; then
      dofins=("${dofins[@]}" "$dofin2/$subdir$dofid2$dofsuf")
      dofinv=(${dofinv[@]} $inv2)
    fi
    if [ -n "$dofin3" ]; then
      dofins=("${dofins[@]}" "$dofin3/$subdir$dofid3$dofsuf")
      dofinv=(${dofinv[@]} $inv3)
    fi

    # create generic transformation submission script
    sub="arguments    = \""
    sub="$sub '$srcdir/$srcpre\$(source)$srcsuf'"
    sub="$sub '$outdir/$subdir$outpre$outid$outsuf'"
    [ -z "$hdrdofs" ] || sub="$sub -source-affdof '$hdrdofs/\$(source)$dofsuf'"
    sub="$sub -threads $threads -interp $interp"
    local i=0
    while [ $i -lt ${#dofins[@]} ]; do
      sub="$sub -dofin"
      [[ ${dofinv[i]} != true ]] || sub="${sub}_i"
      sub="$sub '${dofins[i]}'"
      let i++
    done
    [[ $invert == false ]] || sub="$sub -invert"
    [ ${#spacing[@]} -eq 0 ] || sub="$sub -spacing ${spacing[@]}"
    if [ -n "$ref" ]; then
      sub="$sub -target '$ref'"
    else
      sub="$sub -target '$tgtdir/$tgtpre\$(target)$tgtsuf'"
      [ -z "$hdrdofs" ] || sub="$sub -target-affdof '$hdrdofs/\$(target)$dofsuf'"
    fi
    if [ ${#labels[@]} -gt 0 ]; then
      sub="$sub -labels ${labels[@]}"
    fi
    sub="$sub\""
    sub="$sub\noutput       = $_dagdir/${subdir}transform_\$(source).log"
    sub="$sub\nerror        = $_dagdir/${subdir}transform_\$(source).log"
    sub="$sub\nqueue"
    make_sub_script "transform.sub" "$sub" -executable transform-image

    # create generic resample submission script
    if [[ $resample == true ]] && [ -z "$tgtid" -o -z "$srcid" ]; then
      sub="arguments    = \""
      sub="$sub '$srcdir/$srcpre\$(source)$srcsuf'"
      sub="$sub '$outdir/$subdir$outpre$outid$outsuf'"
      [ -z "$hdrdofs" ] || sub="$sub -source-affdof '$hdrdofs/\$(source)$dofsuf'"
      sub="$sub -threads $threads -interp $interp -dofin Id"
      [ ${#spacing[@]} -eq 0 ] || sub="$sub -spacing ${spacing[@]}"
      [ -z "$ref" ] || sub="$sub -target '$ref'"
      if [ ${#labels[@]} -gt 0 ]; then
        sub="$sub -labels ${labels[@]}"
      fi
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/${subdir}resample_\$(source).log"
      sub="$sub\nerror        = $_dagdir/${subdir}resample_\$(source).log"
      sub="$sub\nqueue"
      make_sub_script "resample.sub" "$sub" -executable transform-image
    fi

    # job to create output directories
    local pre=''
    local is_done=true
    if [ -z "$tgtid$srcid" ]; then
      for id in "${ids[@]}"; do
        pre="$pre\nmkdir -p '$_dagdir/$id' || exit 1"
      done
      for id in "${ids[@]}"; do
        if [ ! -d "$_dagdir/$id" ]; then
          is_done=false
          break
        fi
      done
      pre="$pre\n"
      for id in "${ids[@]}"; do
        pre="$pre\nmkdir -p '$outdir/$id' || exit 1"
      done
      if [[ $is_done == true ]]; then
        for id in "${ids[@]}"; do
          if [ ! -d "$outdir/$id" ]; then
            is_done=false
            break
          fi
        done
      fi
    elif [ -n "$outdir" ] && [[ $outdir != '.' ]]; then
      pre="$pre\nmkdir -p '$outdir' || exit 1"
      [ -d "$outdir" ] || is_done=false
    fi
    if [ -n "$pre" ]; then
      make_script "mkdirs.sh" "$pre"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
      [[ is_done == false ]] || node_done "mkdirs"
    fi

    # add job nodes
    local n=0 job_node
    if [ -n "$tgtid" -a -n "$srcid" ]; then
      id1="$tgtid"
      id2="$srcid"
      job_node="transform_$id1,$id2"
      add_node "$job_node" -subfile "transform.sub" -var "target=\"$id1\"" -var "source=\"$id2\""
      [ -z "$pre" ] || add_edge "$job_node" 'mkdirs'
      if [[ outid == '$(source)' ]]; then
        [ ! -f "$outdir/$outpre$id2$outsuf" ] || node_done "$job_node"
      else
        [ ! -f "$outdir/$outpre$outid$outsuf" ] || node_done "$job_node"
      fi
      n=1 && info "  Added job `printf '%3d of %d' $n $N`"
    elif [ -n "$srcid" ]; then
      id2="$srcid"
      for id1 in "${ids[@]}"; do
        if [[ "$id1" == "$id2" ]]; then
          [[ $resample == true ]] || continue
          job_node="resample_$id1"
          add_node "$job_node" -subfile "resample.sub" -var "target=\"$id1\"" -var "source=\"$id2\""
        else
          job_node="transform_$id2"
          add_node "$job_node" -subfile "transform.sub" -var "target=\"$id1\"" -var "source=\"$id2\""
        fi
        [ -z "$pre" ] || add_edge "$job_node" 'mkdirs'
        [ ! -f "$outdir/$id1/$outpre$id2$outsuf" ] || node_done "$job_node"
        let n++ && info "  Added job `printf '%3d of %d' $n $N`"
      done
    elif [ -n "$tgtid" ]; then
      id1="$tgtid"
      for id2 in "${ids[@]}"; do
        if [[ "$id1" == "$id2" ]]; then
          [[ $resample == true ]] || continue
          job_node="resample_$id1"
          add_node "$job_node" -subfile "resample.sub" -var "target=\"$id1\"" -var "source=\"$id2\""
        else
          job_node="transform_$id2"
          add_node "$job_node" -subfile "transform.sub" -var "target=\"$id1\"" -var "source=\"$id2\""
        fi
        [ -z "$pre" ] || add_edge "$job_node" 'mkdirs'
        [ ! -f "$outdir/$outpre$id2$outsuf" ] || node_done "$job_node"
        let n++ && info "  Added job `printf '%3d of %d' $n $N`"
      done
    else
      for id1 in "${ids[@]}"; do
      for id2 in "${ids[@]}"; do
        if [[ "$id1" == "$id2" ]]; then
          [[ $resample == true ]] || continue
          job_node="resample_$id1"
          add_node "$job_node" -subfile "resample.sub" -var "target=\"$id1\"" -var "source=\"$id2\""
        else
          job_node="transform_$id1,$id2"
          add_node "$job_node" -subfile "transform.sub" -var "target=\"$id1\"" -var "source=\"$id2\""
        fi
        [ -z "$pre" ] || add_edge "$job_node" 'mkdirs'
        [ ! -f "$outdir/$id1/$outpre$id2$outsuf" ] || node_done "$job_node"
        let n++ && info "  Added job `printf '%3d of %d' $n $N`"
      done; done
    fi

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}

# ------------------------------------------------------------------------------
# add node for evaluation of segmentation label overlaps
evaluate_overlap_node()
{
  local node=
  local parent=()
  local ids=()
  local imgdir=
  local imgpre=
  local imgsuf='.nii.gz'
  local tgtid=
  local tgtdir=
  local tgtpre='$imgpre'
  local tgtsuf='$imgsuf'
  local padding=0
  local labels=()
  local metric="dice"
  local outdir=
  local outpre=
  local outsuf=".csv"
  local table=
  local delim=","
  local digits=5

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids "$@"; shift ${#ids[@]}; ;;
      -imgdir)   optarg imgdir $1 "$2"; shift; ;;
      -imgpre)   imgpre="$2"; shift; ;;
      -imgsuf)   imgsuf="$2"; shift; ;;
      -tgtdir)   optarg tgtdir $1 "$2"; shift; ;;
      -tgtid)    tgtid="$2";  shift; ;;
      -tgtpre)   tgtpre="$2"; shift; ;;
      -tgtsuf)   tgtsuf="$2"; shift; ;;
      -bgvalue)  optarg padding $1 "$2"; shift; ;;
      -metric)
        metric=()
        optargs metric "$@"
        shift ${#metric[@]}
        ;;
      -outdir)   optarg outdir $1 "$2"; shift; ;;
      -outpre)   outpre="$2"; shift; ;;
      -outsuf)   outsuf="$2"; shift; ;;
      -table)    optarg table $1 "$2"; shift; ;;
      -delim)    optarg delim $1 "$2"; shift; ;;
      -digits)   optarg digits $1 "$2"; shift; ;;
      -*) error "evaluate_overlap_node: invalid option: $1"; ;;
      *)
        [ -z "$node" ] || error "evaluate_overlap_node: too many arguments"
        node=$1; ;;
    esac
    shift
  done
  [ -n "$node" ] || error "evaluate_overlap_node: missing name argument"
  if [ -n "$tgtid" ]; then
    [ ${#ids[@]} -ge 1 ] || error "evaluate_overlap_node: not enough -subjects specified"
  else
    [ ${#ids[@]} -ge 2 ] || error "evaluate_overlap_node: not enough -subjects specified"
  fi
  [ -n "$tgtdir" ] || tgtdir="$imgdir"
  [[ $tgtpre != '$imgpre' ]] || tgtpre="$imgpre"
  [[ $tgtsuf != '$imgsuf' ]] || tgtsuf="$imgsuf"

  # number of jobs
  local N=1
  if [ -n "$tgtid" ]; then
    if [ -n "$table" ]; then
      N=1
    else
      let N="${#ids[@]}"  
    fi
  else
    let N="${#ids[@]} * (${#ids[@]} - 1)"
  fi

  # add SUBDAG node
  info "Adding node $node..."
  begin_dag $node -splice || {

    # create generic evaluate-overlap submission script
    local sub="arguments    = \""
    if [ -n "$tgtid" ]; then
      sub="$sub '$tgtdir/$tgtpre$tgtid$tgtsuf'"
      if [ -n "$table" ]; then
        sub="$sub -images '$_dagdir/images.csv'"
        sub="$sub -table '$table'"
      else
        sub="$sub '$imgdir/$imgpre\$(source)$imgsuf'"
        sub="$sub -table '$outdir/$outpre\$(source)$outsuf'"
      fi
    else
      sub="$sub '$imgdir/\$(target)/$imgpre\$(target)$imgsuf'"
      sub="$sub '$imgdir/\$(target)/$imgpre\$(source)$imgsuf'"
      sub="$sub -table '$outdir/\$(target)/$outpre\$(source)$outsuf'"
    fi
    sub="$sub -labels ${labels[@]} -metric ${metric[@]}"
    sub="$sub -precision $digits -delim '$delim'"
    sub="$sub -threads $threads\""
    if [ -n "$tgtid" ]; then
      if [ -n "$table" ]; then
        sub="$sub\noutput       = $_dagdir/evaluate.log"
        sub="$sub\nerror        = $_dagdir/evaluate.log"
      else
        sub="$sub\noutput       = $_dagdir/evaluate_\$(source).log"
        sub="$sub\nerror        = $_dagdir/evaluate_\$(source).log"
      fi
    else
      sub="$sub\noutput       = $_dagdir/evaluate_\$(target),\$(source).log"
      sub="$sub\nerror        = $_dagdir/evaluate_\$(target),\$(source).log"
    fi
    sub="$sub\nqueue"
    make_sub_script "evaluate.sub" "$sub" -executable evaluate-overlap

    # job to create output directories
    local pre=''
    local is_done=true
    if [ -n "$tgtid" ]; then
      if [ -n "$table" ]; then
        local csvdir="$(dirname "$table")"
        if [[ $csvdir != '.' ]]; then
          pre="$pre\nmkdir -p '$csvdir' || exit 1"
          [ -d "$csvdir" ] || is_done=false
        fi
      elif [ -n "$outdir" ]; then
        if [[ $outdir != '.' ]]; then
          pre="$pre\nmkdir -p '$outdir' || exit 1"
          [ -d "$outdir" ] || is_done=false
        fi
      fi
    elif [ -n "$outdir" ]; then
      for id in ${ids[@]}; do
        pre="$pre\nmkdir -p '$outdir/$id' || exit 1"
      done
      for id in ${ids[@]}; do
        if [ ! -d "$outdir/$id" ]; then
          is_done=false
          break
        fi
      done
    fi
    if [ -n "$pre" ]; then
      make_script "mkdirs.sh" "$pre"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
      [[ is_done == false ]] || node_done "mkdirs"
    fi

    # add job nodes
    local job_node sublst
    if [ -n "$tgtid" ]; then
      if [ -n "$table" ]; then
        sublst="$_dagdir/images.csv"
        echo "$topdir/$imgdir" > "$sublst"
        for id in ${ids[@]}; do
          if [[ "$id" != "$tgtid" ]]; then
            echo "$imgpre$id$imgsuf" >> "$sublst"
          fi
        done
        job_node="evaluate"
        add_node "$job_node" -subfile "evaluate.sub"
        [ -z "$pre" ] || add_edge "$job_node" "mkdirs"
        [ ! -f "$table" ] || node_done "$job_node"
      else
        local n=0
        for id in ${ids[@]}; do
          [[ "$id" != "$tgtid" ]] || continue
          job_node="evaluate_$id"
          add_node "$job_node" -subfile "evaluate.sub" -var "source=\"$id\""
          [ -z "$pre" ] || add_edge "$job_node" "mkdirs"
          [ ! -f "$outdir/$outpre$id$outsuf" ] || node_done "$job_node"
          let n++ && info "  Added job `printf '%3d of %d' $n $N`"
        done
      fi
    else
      local n=0
      for id1 in "${ids[@]}"; do
      for id2 in "${ids[@]}"; do
        [[ "$id1" != "$id2" ]] || continue
        job_node="evaluate_$id1,$id2"
        add_node "$job_node" -subfile "evaluate.sub" -var "target=\"$id1\"" -var "source=\"$id2\""
        [ -z "$pre" ] || add_edge "$job_node" "mkdirs"
        [ ! -f "$outdir/$id1/$outpre$id2$outsuf" ] || node_done "$job_node"
        let n++ && info "  Added job `printf '%3d of %d' $n $N`"
      done; done
    fi

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}

# ------------------------------------------------------------------------------
# add node to invert transformations
invert_dof_node()
{
  local node=
  local parent=()
  local ids=()
  local idlst=()
  local dofins=
  local dofdir=
  local dofsuf='.dof.gz'
  local group=1

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent) optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids "$@"; shift ${#ids[@]}; ;;
      -sublst) optarg idlst $1 "$2"; shift; ;;
      -dofins) optarg dofins $1 "$2"; shift; ;;
      -dofdir) optarg dofdir $1 "$2"; shift; ;;
      -dofsuf) optarg dofsuf $1 "$2"; shift; ;;
      -group) optarg group $1 "$2"; shift; ;;
      -*) error "invert_dof_node: invalid option: $1"; ;;
      *)
        [ -z "$node" ] || error "invert_dof_node: too many arguments"
        node=$1; ;;
    esac
    shift
  done
  [ -n "$node"   ] || error "invert_dof_node: missing name argument"
  [ -n "$dofins" ] || error "invert_dof_node: missing -dofins argument"
  [ -n "$dofdir" ] || error "invert_dof_node: missing -dofdir argument"

  info "Adding node $node..."
  begin_dag $node -splice || {

    # read IDs from specified text file
    [ ${#ids[@]} -gt 0 ] || read_sublst ids "$idlst"

    # create generic invert-dof submission script
    local sub="arguments = \"'$dofins/\$(id).dof.gz' '$dofdir/\$(id).dof.gz' -threads $threads\""
    sub="$sub\noutput    = $_dagdir/invert_\$(id).log"
    sub="$sub\nerror     = $_dagdir/invert_\$(id).log"
    sub="$sub\nqueue"
    make_sub_script "invert.sub" "$sub" -executable invert-dof

    # node to create output directories
    local deps=()
    if [[ "$dofdir" != '.' ]]; then
      make_script "mkdirs.sh" "mkdir -p '$dofdir' || exit 1"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
      [ ! -d "$dofdir" ] || node_done "mkdirs"
      deps=('mkdirs')
    fi

    # add invert-dof nodes to DAG
    if [ $group -gt 1 ]; then
      local grpids i=0
      while [ $i -lt ${#ids[@]} ]; do
        grpids=("${ids[@]:$i:$group}")
        let j="$i + ${#grpids[@]} - 1"
        add_node "invert_$i-$j" -subfile "invert.sub" -grpvar "id" -grpval "${grpids[@]}"       
        for dep in ${deps[@]}; do
          add_edge "invert_$i-$j" "$dep"
        done
        is_done=true
        for id in ${grpids[@]}; do
          if [ ! -f "$dofdir/$id.dof.gz" ]; then
            is_done=false
            break
          fi
        done
        [[ is_done == false ]] || node_done "invert_$i-$j"
        let i="$j + 1"
      done
    else
      for id in ${ids[@]}; do
        add_node "invert_$id" -subfile "invert.sub" -var "id=\"$id\""
        for dep in ${deps[@]}; do
          add_edge "invert_$id" "$dep"
        done
        [ ! -f "$dofdir/$id.dof.gz" ] || node_done "invert_$id"
      done
    fi

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}

# ------------------------------------------------------------------------------
# add node for averaging of transformations
average_dofs_node()
{
  local node=
  local parent=()
  local ids=()
  local doflst=
  local dofins=
  local dofdir=
  local dofid=
  local dofpre=
  local dofsuf='.dof.gz'
  local outpre=
  local outsuf=
  local options='-v -all'
  local group=1

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)        optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects)      optargs ids    "$@"; shift ${#ids[@]}; ;;
      -doflst)        optarg  doflst $1 "$2"; shift; ;;
      -dofins)        optarg  dofins $1 "$2"; shift; ;;
      -dofdir)        optarg  dofdir $1 "$2"; shift; ;;
      -dofsuf)        optarg  dofsuf $1 "$2"; shift; ;;
      -dofpre)        dofpre="$2"; shift; ;;
      -dofid)         dofid="$2"; shift; ;;
      -outpre)        outpre="$2"; shift; ;;
      -outsuf)        outsuf="$2"; shift; ;;
      -invert)        options="$options -invert";  ;;
      -inverse)       options="$options -inverse";  ;;
      -inverse-dofs)  options="$options -inverse-dofs";  ;;
      -norigid)       options="$options -norigid";  ;;
      -notranslation) options="$options -notranslation";  ;;
      -norotation)    options="$options -norotation";  ;;
      -noscaling)     options="$options -noscaling";  ;;
      -noshearing)    options="$options -noshearing";  ;;
      -dofs)          options="$options -dofs"; ;;
      -group)         optarg group $1 "$2"; shift; ;;
      -*)             error "average_dofs_node: invalid option: $1"; ;;
      *)              [ -z "$node" ] || error "average_dofs_node: too many arguments"
                      node=$1; ;;
    esac
    shift
  done
  [ -n "$node"   ] || error "average_dofs_node: missing name argument"
  [ -n "$dofins" ] || error "average_dofs_node: missing -dofins argument"
  [ -n "$outpre" ] || outpre="$dofpre"
  [ -n "$outsuf" ] || outsuf="$dofsuf"

  info "Adding node $node..."
  begin_dag $node -splice || {

    # weights of input transformations
    if [ -z "$doflst" ]; then
      [ ${#ids[@]} -gt 0 ] || error "average_dofs_node: missing -subjects or -doflst argument"
      local dofnames=
      for id in "${ids[@]}"; do
        dofnames="$dofnames$id\t1\n"
      done
      doflst="$_dagdir/dofavg.tsv"
      write "$doflst" "$dofnames"
    fi

    # create generic dofaverage submission script
    local sub="arguments = \""
    if [ -n "$dofid" ]; then
      sub="$sub'$dofdir/$outpre$dofid$outsuf' $options -threads $threads"
      sub="$sub -dofdir '$dofins' -dofnames '$doflst' -prefix '$dofpre' -suffix '$dofsuf'"
      sub="$sub\""
      sub="$sub\noutput    = $_dagdir/dofavg_$dofid.log"
      sub="$sub\nerror     = $_dagdir/dofavg_$dofid.log"
    else
      [ -n "$dofpre" ] || dofpre='$(id)/'
      sub="$sub'$dofdir/$outpre\$(id)$outsuf' $options -threads $threads -add-identity-for-dofname '\$(id)'"
      sub="$sub -dofdir '$dofins' -dofnames '$doflst' -prefix '$dofpre' -suffix '$dofsuf'"
      sub="$sub\""
      sub="$sub\noutput    = $_dagdir/dofavg_\$(id).log"
      sub="$sub\nerror     = $_dagdir/dofavg_\$(id).log"
    fi
    sub="$sub\nqueue"
    make_sub_script "dofavg.sub" "$sub" -executable average-dofs

    # node to create output directories
    local deps=()
    if [ -n "$dofdir" ] && [[ "$dofdir" != '.' ]]; then
      make_script "mkdirs.sh" "mkdir -p '$dofdir' || exit 1"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
      [ ! -d "$dofdir" ] || node_done "mkdirs"
      deps=('mkdirs')
    fi

    # add dofaverage nodes to DAG
    if [ -n "$dofid" ]; then
      add_node "dofavg_$dofid" -subfile "dofavg.sub"
      for dep in ${deps[@]}; do
        add_edge "dofavg_$dofid" "$dep"
      done
      [ ! -f "$dofdir/$dofid$dofsuf" ] || node_done "dofavg_$dofid"
    else
      [ ${#ids[@]} -gt 0 ] || read_sublst ids "$doflst"
      if [ $group -gt 1 ]; then
        local grpids i=0
        while [ $i -lt ${#ids[@]} ]; do
          grpids=("${ids[@]:$i:$group}")
          let j="$i + ${#grpids[@]} - 1"
          add_node "dofavg_$i-$j" -subfile "dofavg.sub" -grpvar "id" -grpval "${grpids[@]}"
          for dep in ${deps[@]}; do
            add_edge "dofavg_$i-$j" "$dep"
          done
          is_done=true
          for id in ${grpids[@]}; do
            if [ ! -f "$dofdir/$id$dofsuf" ]; then
              is_done=false
              break
            fi
          done
          [[ is_done == false ]] || node_done "dofavg_$i-$j"
          let i="$j + 1"
        done
      else
        for id in "${ids[@]}"; do
          add_node "dofavg_$id" -subfile "dofavg.sub" -var "id=\"$id\""
          for dep in ${deps[@]}; do
            add_edge "dofavg_$id" "$dep"
          done
          [ ! -f "$dofdir/$id$dofsuf" ] || node_done "dofavg_$id"
        done
      fi
    fi

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}

# ------------------------------------------------------------------------------
# add node for composition of transformations
compose_dofs_node()
{
  local node=
  local parent=()
  local ids=()
  local idlst=
  local dofid=
  local dofid1=
  local dofid2=
  local dofid3=
  local dofdir=
  local dofin1=
  local dofin2=
  local dofin3=
  local dofsuf='.dof.gz'
  local options=''
  local group=1

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids    "$@"; shift ${#ids[@]}; ;;
      -sublst)   optarg  idlst   $1 "$2"; shift; ;;
      -dofid)    optarg  dofid   $1 "$2"; shift; ;;
      -dofid1)   optarg  dofid1  $1 "$2"; shift; ;;
      -dofid2)   optarg  dofid2  $1 "$2"; shift; ;;
      -dofid3)   optarg  dofid3  $1 "$2"; shift; ;;
      -dofdir)   optarg  dofdir  $1 "$2"; shift; ;;
      -dofin1)   optarg  dofin1  $1 "$2"; shift; ;;
      -dofin2)   optarg  dofin2  $1 "$2"; shift; ;;
      -dofin3)   optarg  dofin3  $1 "$2"; shift; ;;
      -dofsuf)   optarg  dofsuf  $1 "$2"; shift; ;;
      -notranslation) options="$options -notranslation";  ;;
      -norotation)    options="$options -norotation";  ;;
      -noscaling)     options="$options -noscaling";  ;;
      -noshearing)    options="$options -noshearing";  ;;
      -group) optarg group $1 "$2"; shift; ;;
      -*)        error "compose_dofs_node: invalid option: $1"; ;;
      *)         [ -z "$node" ] || error "compose_dofs_node: too many arguments"
                 node=$1; ;;
    esac
    shift
  done
  [ -n "$node" ] || error "compose_dofs_node: missing name argument"
  [ -n "$dofdir" ] || error "compose_dofs_node: missing output -dofdir argument"
  [ -n "$dofin1" ] || error "compose_dofs_node: missing input -dofin1 argument"
  [ -n "$dofin2" ] || error "compose_dofs_node: missing input -dofin2 argument"
  if [[ $dofid1 == '$(target)' ]] && [[ $dofid2 == '$(source)' ]]; then
    [ -z "$dofid" ] || [[ "$dofid" == '$(target)/$(source)' ]] || {
      error "compose_dofs_node: output -dofid cannot be set when -dofid1 '$(target)' -dofid2 '$(source)'"
    }
    [ -z "$dofin3" ] || {
      error "compose_dofs_node: third transformation not allowed when -dofid1 '$(target)' -dofid2 '$(source)'"
    }
    dofid='$(target)/$(source)'
  elif [ -z "$dofid" ]; then
    if [ ${#ids[@]} -eq 0 -a -z "$idlst" ]; then
      error "compose_dofs_node: missing -subjects or -sublst argument"
    fi
    dofid='$(id)'
  elif [ ${#ids[@]} -gt 0 -o -n "$idlst" ]; then
    error "compose_dofs_node: options -dofid and -subjects/-sublst are mutually exclusive"
  fi
  [ -z "$dofin1" ] || [ -n "$dofid1" ] || dofid1="$dofid"
  [ -z "$dofin2" ] || [ -n "$dofid2" ] || dofid2="$dofid"
  [ -z "$dofin3" ] || [ -n "$dofid3" ] || dofid3="$dofid"

  info "Adding node $node..."
  begin_dag $node -splice || {

    # create generic dofcombine submission script
    local sub="arguments = \"'$dofin1/$dofid1$dofsuf' '$dofin2/$dofid2$dofsuf'"
    [ -z "$dofin3" ] || sub="$sub '$dofin3/$dofid3$dofsuf'"
    sub="$sub '$dofdir/$dofid$dofsuf' $options -threads $threads\""
    sub="$sub\noutput    = $_dagdir/compose_${dofid//\//,}.log"
    sub="$sub\nerror     = $_dagdir/compose_${dofid//\//,}.log"
    sub="$sub\nqueue"
    make_sub_script "compose.sub" "$sub" -executable compose-dofs

    # node to create output directories
    local deps=()
    local pre=
    local is_done=true
    if [[ $dofid == '$(target)/$(source)' ]]; then
      [ ${#ids[@]} -gt 0 ] || read_sublst ids "$idlst"
      for id in "${ids[@]}"; do
        pre="$pre\nmkdir -p '$dofdir/$id' || exit 1"
      done
      for id in "${ids[@]}"; do
        if [ ! -d "$dofdir/$id" ]; then
          is_done=false
          break
        fi
      done
    elif [ -n "$dofdir" ] && [[ "$dofdir" != '.' ]]; then
      pre="mkdir -p '$dofdir' || exit 1"
      [ -d "$dofdir" ] || is_done=false
    fi
    if [ -n "$pre" ]; then
      make_script "mkdirs.sh" "$pre"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
      [[ is_done == false ]] || node_done "mkdirs"
      deps=('mkdirs')
    fi

    # add dofcombine nodes to DAG
    if [[ "$dofid" == '$(target)/$(source)' ]]; then
      [ ${#ids[@]} -gt 0 ] || read_sublst ids "$idlst"
      for id1 in "${ids[@]}"; do
        if [ $group -gt 1 ]; then
          local i=0 j k grpids
          while [ $i -lt ${#ids[@]} ]; do
            grpids=("${ids[@]:$i:$group}")
            let j="$i + ${#grpids[@]} - 1"
            k=0
            while [ $k -lt ${#grpids[@]} ]; do
              if [[ ${grpids[k]} == $id1 ]]; then
                unset grpids[k]
                grpids=("${grpids[@]}")
                break
              fi
            done
            add_node "compose_$id1,$i-$j" -subfile "compose.sub" -var "target=\"$id1\"" -grpvar "source" -grpval "${grpids[@]}"
            for dep in ${deps[@]}; do
              add_edge "compose_$id1,$i-$j" "$dep"
            done
            is_done=true
            for id2 in ${grpids[@]}; do
              if [ ! -f "$dofdir/$id1/$id2$dofsuf" ]; then
                is_done=false
                break
              fi
            done
            [[ is_done == false ]] || node_done "compose_$id1,$i-$j"
            let i="$j + 1"
          done
        else
          for id2 in "${ids[@]}"; do
            [[ $id1 != $id2 ]] || continue
            add_node "compose_$id1,$id2" -subfile "compose.sub" -var "target=\"$id1\"" -var "source=\"$id2\""
            for dep in ${deps[@]}; do
              add_edge "compose_$id1,$id2" "$dep"
            done
            [ ! -f "$dofdir/$id1/$id2$dofsuf" ] || node_done "compose_$id1,$id2"
          done
        fi
      done
    elif [[ "$dofid" == '$(id)' ]]; then
      [ ${#ids[@]} -gt 0 ] || read_sublst ids "$idlst"
      if [ $group -gt 1 ]; then
        local grpids i=0
        while [ $i -lt ${#ids[@]} ]; do
          grpids=("${ids[@]:$i:$group}")
          let j="$i + ${#grpids[@]} - 1"
          add_node "compose_$i-$j" -subfile "compose.sub" -grpvar "id" -grpval "${grpids[@]}"
          for dep in ${deps[@]}; do
            add_edge "compose_$i-$j" "$dep"
          done
          is_done=true
          for id in ${grpids[@]}; do
            if [ ! -f "$dofdir/$id$dofsuf" ]; then
              is_done=false
              break
            fi
          done
          [[ is_done == false ]] || node_done "compose_$i-$j"
          let i="$j + 1"
        done
      else
        for id in "${ids[@]}"; do
          add_node "compose_$id" -subfile "compose.sub" -var "id=\"$id\""
          for dep in ${deps[@]}; do
            add_edge "compose_$id" "$dep"
          done
          [ ! -f "$dofdir/$id$dofsuf" ] || node_done "compose_$id"
        done
      fi
    else
      add_node "compose_$dofid" -subfile "compose.sub"
      for dep in ${deps[@]}; do
        add_edge "compose_$dofid" "$dep"
      done
      [ ! -f "$dofdir/$dofid$dofsuf" ] || node_done "compose_$dofid"
    fi

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}

# ------------------------------------------------------------------------------
# add node for computation of average image
average_images_node()
{
  local node=
  local parent=()
  local ids=()
  local idlst=()
  local refid=
  local refdir=
  local refpre=
  local refsuf=
  local imgdir=
  local imgpre=
  local imgsuf='.nii.gz'
  local dofin1=
  local dofin2=
  local dofin3=
  local dofid1=
  local dofid2=
  local dofid3=
  local invdof1=false
  local invdof2=false
  local invdof3=false
  local dofpre=
  local dofsuf='.dof.gz'
  local dofinv='false'
  local average=
  local stdev=
  local threshold=0.5
  local options=''
  local label margin bgvalue

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids    "$@"; shift ${#ids[@]}; ;;
      -sublst)   optarg  idlst   $1 "$2"; shift; ;;
      -refid)    refid="$2"; shift; ;;
      -refdir)   optarg refdir $1 "$2"; shift; ;;
      -refpre)   refpre="$2"; shift; ;;
      -refsuf)   refsuf="$2"; shift; ;;
      -imgdir)   optarg imgdir  $1 "$2"; shift; ;;
      -imgpre)   imgpre="$2"; shift; ;;
      -imgsuf)   imgsuf="$2"; shift; ;;
      -dofdir)   optarg dofin1 $1 "$2"; shift; ;;
      -dofin1)   dofin1="$2"; shift; ;;
      -dofin2)   dofin2="$2"; shift; ;;
      -dofin3)   dofin3="$2"; shift; ;;
      -dofid1)   dofid1="$2"; shift; ;;
      -dofid2)   dofid2="$2"; shift; ;;
      -dofid3)   dofid3="$2"; shift; ;;
      -dofpre)   dofpre="$2"; shift; ;;
      -dofsuf)   dofsuf="$2"; shift; ;;
      -dofinv)
        invdof1=true
        invdof2=true
        invdof3=true
        ;;
      -dofinv1) optarg dofinv1 $1 "$2"; shift; ;;
      -dofinv2) optarg dofinv2 $1 "$2"; shift; ;;
      -dofinv3) optarg dofinv3 $1 "$2"; shift; ;;
      -output|-mean|-average)
        optarg average $1 "$2"
        shift; ;;
      -sd|-sdev|-stdev|-stddev|-sigma)
        optarg stdev $1 "$2"
        shift; ;;
      -spacing|-voxelsize|-resolution)
        local voxelsize
        optargs voxelsize "$@"
        if [ ${#voxelsize[@]} -gt 3 ]; then
          error "average_images_node: too many -spacing, -voxelsize, -resolution arguments"
        fi
        shift ${#voxelsize[@]}
        options="$options -size ${voxelsize[@]}"
        ;;
      -threshold)
        optarg threshold $1 "$2"; shift
        ;;
      -margin)
        optarg margin $1 "$2"; shift
        options="$options -margin $margin";;
      -bgvalue|-padding)
        optarg bgvalue $1 "$2"; shift
        options="$options -padding $bgvalue";;
      -normalize|-normalization)
        local arg=
        optarg arg $1 "$2"; shift
        options="$options -normalization $arg"
        ;;
      -rescale|-rescaling)
        local arg=
        optarg arg $1 "$2"; shift
        options="$options -rescaling $arg"
        ;;
      -sharpen)
        local arg=
        optarg arg $1 "$2"; shift
        options="$options -sharpen $arg"
        ;;
      -label|-labels)
        local args=
        optargs args "$@"; shift ${#args[@]}
        options="$options -label ${args[@]}"
        ;;
      -dtype)
        local arg=
        optarg arg $1 "$2"; shift
        options="$options -dtype $arg"
        ;;
      -*)
        error "average_images_node: invalid option: $1"; ;;
      *)
        [ -z "$node" ] || error "average_images_node: too many arguments: $@"
        node="$1"; ;;
    esac
    shift
  done
  [ -n "$node" ] || error "average_images_node: missing name argument"
  [ -n "$average" ] || error "average_images_node: missing -output, -average, or -mean argument"
  [ -z "$imgdir" ] || imgpre="$imgdir/$imgpre"
  [ -n "$refdir" ] || refdir="$imgdir"
  [ -n "$refsuf" ] || refsuf="$imgsuf"
  [ -z "$refid" ] || options="$options -reference '$refdir/$refpre$refid$refsuf'"

  info "Adding node $node..."
  begin_dag $node -splice || {

    # write image list with optional transformations and weights
    local imglst="$_dagdir/images.csv"
    local images="$topdir\n"
    local weights=()
    if [ -n "$idlst" ]; then
      [ ${#ids[@]} -eq 0 ] || error "average_images_node: options -subjects and -sublst are mutually exclusive"
      local pair line
      while read line; do
        pair=($line)
        ids=("${ids[@]}" "${pair[0]}")
        weights=("${weights[@]}" "${pair[1]}")
      done < "$idlst"
    fi
    local i=0
    while [ $i -lt ${#ids[@]} ]; do
      images="$images\"$imgpre${ids[i]}$imgsuf\""
      if [ -n "$dofin1" ] && [[ $dofid1 != false ]]; then
        images="$images,\""
        [[ $invdof1 != true ]] || images="${images}inv:"
        images="$images$dofin1/$dofpre$dofid1"
        if [ -z "$dofid1" ]; then
          images="${ids[i]}"
        fi
        images="$images$dofsuf\""
      fi
      if [ -n "$dofin2" ] && [[ $dofid2 != false ]]; then
        images="$images,\""
        [[ $invdof2 != true ]] || images="${images}inv:"
        images="$images$dofin2/$dofpre$dofid2"
        if [ -z "$dofid2" ]; then
          images="${ids[i]}"
        fi
        images="$images$dofsuf\""
      fi
      if [ -n "$dofin3" ] && [[ $dofid3 != false ]]; then
        images="$images,\""
        [[ $invdof3 != true ]] || images="${images}inv:"
        images="$images$dofin3/$dofpre$dofid3"
        if [ -z "$dofid3" ]; then
          images="${ids[i]}"
        fi
        images="$images$dofsuf\""
      fi
      if [ $i -lt ${#weights[@]} ]; then
        images="$images,${weights[i]}"
      else
        images="$images,1"
      fi
      images="$images\n"
      let i++
    done
    write "$imglst" "$images"

    # node to create output directories
    local deps=()
    local pre=
    local avgdir="$(dirname "$average")"
    local is_done=true
    if [[ "$avgdir" != '.' ]]; then
      pre="mkdir -p '$avgdir' || exit 1"
      [ -d "$avgdir" ] || is_done=false
    fi
    local stddir="$(dirname "$stdev")"
    if [[ "$stddir" != '.' ]]; then
      pre="mkdir -p '$stddir' || exit 1"
      [ -d "$stddir" ] || is_done=false
    fi
    if [ -n "$pre" ]; then
      make_script "mkdirs.sh" "$pre"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
      [[ is_done == false ]] || node_done "mkdirs"
      deps=('mkdirs')
    fi

    # add average node to DAG
    local sub="arguments = \"'$average' -v -images '$imglst' -threshold $threshold -delim , -threads $threads $options\""
    [ -z "$stdev" ] || sub="$sub -stdev '$stdev'"
    sub="$sub\noutput    = $_dagdir/average.log"
    sub="$sub\nerror     = $_dagdir/average.log"
    sub="$sub\nqueue"
    add_node "average" -sub "$sub" -executable average-images
    for dep in ${deps[@]}; do
      add_edge "average" "$dep"
    done
    if [ -f "$average" ]; then
      if [ -z "$stdev" ] || [ -f "$stdev" ]; then
        node_done average
      fi
    fi

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}

# ------------------------------------------------------------------------------
# compute per-voxel statistics of co-registered images
aggregate_images_node()
{
  local node=
  local parent=()
  local ids=()
  local imgdir=
  local imgpre=''
  local imgsuf='.nii.gz'
  local output=
  local mode='mean'
  local normalization=
  local padding=
  local alpha=

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent) optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids "$@"; shift ${#ids[@]}; ;;
      -mode) optarg mode $1 "$2"; shift; ;;
      -imgdir) optarg imgdir $1 "$2"; shift; ;;
      -imgpre) imgpre="$2"; shift; ;;
      -imgsuf) imgsuf="$2"; shift; ;;
      -output) optarg output $1 "$2"; shift; ;;
      -padding|-bgvalue) optarg padding $1 "$2"; shift; ;;
      -normalize|-normalization) optarg normalization $1 "$2"; shift; ;;
      -alpha) optarg alpha $1 "$2"; shift; ;;
      -*) error "aggregate_images_node: invalid option: $1"; ;;
      *)
        [ -z "$node" ] || error "aggregate_images_node: too many arguments"
        node=$1; ;;
    esac
    shift
  done
  [ -n "$node"   ] || error "aggregate_images_node: missing name argument"
  [ -n "$imgdir" ] || error "aggregate_images_node: missing -imgdir argument"
  [ -n "$output" ] || error "aggregate_images_node: missing -output argument"

  info "Adding node $node..."
  begin_dag $node -splice || {

    # create aggregate-images submission script
    local sub="arguments = \"$mode"
    for id in ${ids[@]}; do
      sub="$sub '$imgdir/$imgpre${id}$imgsuf'"
    done
    [ -z "$alpha" ] || sub="$sub -alpha $alpha"
    [ -z "$normalization" ] || sub="$sub -normalization $normalization"
    [ -z "$padding" ] || sub="$sub -padding $padding"
    sub="$sub -output '$output' -threads $threads"
    sub="$sub\""
    sub="$sub\noutput    = $_dagdir/aggregate_images.log"
    sub="$sub\nerror     = $_dagdir/aggregate_images.log"
    sub="$sub\nqueue"
    make_sub_script "aggregate_images.sub" "$sub" -executable aggregate-images

    # node to create output directory
    local deps=()
    local outdir="$(dirname "$output")"
    if [[ "$outdir" != '.' ]]; then
      make_script "mkdirs.sh" "mkdir -p '$outdir' || exit 1"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
      [ ! -d "$outdir" ] || node_done "mkdirs"
      deps=('mkdirs')
    fi

    # add sub-nodes to DAG
    add_node "aggregate" -subfile "aggregate_images.sub"
    for dep in ${deps[@]}; do
      add_edge "aggregate" "$dep"
    done
    [ ! -f "$output" ] || node_done "aggregate"

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}

# ------------------------------------------------------------------------------
# modify image header
edit_image_node()
{
  local node=
  local parent=()
  local ids=()
  local idlst=
  local imgid=
  local imgdir=
  local imgpre=''
  local imgsuf='.nii.gz'
  local outdir=
  local outpre='$imgpre'
  local outsuf='$imgsuf'
  local dofid=
  local dofins=
  local dofpre=''
  local dofsuf='.dof.gz'
  local sform='false'

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent) optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids "$@"; shift ${#ids[@]}; ;;
      -sublst) optarg idlst $1 "$2"; shift; ;;
      -imgdir) optarg imgdir $1 "$2"; shift; ;;
      -imgid)  optarg imgid $1 "$2"; shift; ;;
      -imgpre) imgpre="$2"; shift; ;;
      -imgsuf) imgsuf="$2"; shift; ;;
      -outdir) optarg outdir $1 "$2"; shift; ;;
      -outpre) outpre="$2"; shift; ;;
      -outsuf) outsuf="$2"; shift; ;;
      -dofins) optarg dofins $1 "$2"; shift; ;;
      -dofid)  optarg dofin $1 "$2"; shift; ;;
      -dofpre) dofpre="$2"; shift; ;;
      -dofsuf) dofsuf="$2"; shift; ;;
      -qform) sform='false'; ;;
      -sform) sform='true'; ;;
      -*) error "edit_image_node: invalid option: $1"; ;;
      *)
        [ -z "$node" ] || error "edit_image_node: too many arguments"
        node=$1; ;;
    esac
    shift
  done
  [ -n "$node" ] || error "edit_image_node: missing name argument"
  [ -n "$imgdir" ] || error "edit_image_node: missing -imgdir argument"
  [ -n "$outdir" ] || error "edit_image_node: missing -outdir argument"
  [[ $outpre != '$imgpre' ]] || outpre="$imgpre"
  [[ $outsuf != '$imgsuf' ]] || outsuf="$imgsuf"

  if [ -n "$imgid" ]; then
    [ -z "$idlst" -a ${#ids[@]} -eq 0 ] || {
      error "edit_image_node: options -imgid, -subjects, and -sublst are mutually exclusive"
    }
    ids=("$imgid")
  elif [ -n "$idlst" ]; then
    [ ${#ids[@]} -eq 0 ] || {
      error "edit_image_node: options -imgid, -subjects, and -sublst are mutually exclusive"
    }
    read_sublst ids "$idlst"
  fi

  info "Adding node $node..."
  begin_dag $node -splice || {

    # create generic edit-image submission script
    local sub="arguments = \""
    sub="$sub'$imgdir/$imgpre\$(id)$imgsuf' '$outdir/$outpre\$(id)$outsuf' -threads $threads"
    if [ -n "$dofins" ]; then
      local dofopt='-dofin'
      [[ $sform == false ]] || dofopt='-putdof'
      if [ -n "$dofid" ]; then
        sub="$sub $dofopt $dofins/$dofid$dofsuf"
      else
        sub="$sub $dofopt $dofins/\$(id)$dofsuf"
      fi
    fi
    sub="$sub\""
    sub="$sub\noutput    = $_dagdir/edit_image_\$(id).log"
    sub="$sub\nerror     = $_dagdir/edit_image_\$(id).log"
    sub="$sub\nqueue"
    make_sub_script "edit_image.sub" "$sub" -executable edit-image

    # node to create output directories
    local deps=()
    if [[ "$outdir" != '.' ]]; then
      make_script "mkdirs.sh" "mkdir -p '$outdir' || exit 1"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
      [ ! -d "$outdir" ] || node_done "mkdirs"
      deps=('mkdirs')
    fi

    # add invert-dof nodes to DAG
    for id in "${ids[@]}"; do
      add_node "edit_image_$id" -subfile "edit_image.sub" -var "id=\"$id\""
      for dep in ${deps[@]}; do
        add_edge "edit_image_$id" "$dep"
      done
      [ ! -f "$outdir/$outpre$id$outsuf" ] || node_done "edit_image_$id"
    done

  }; end_dag
  add_edge $node ${parent[@]}
  info "Adding node $node... done"
}
