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
init_dofs_node()
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
    make_script "mkdirs.sh" "mkdir -p '$dofdir' || exit 1"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.log\nqueue"

    # add dofcreate nodes to DAG
    if [ -n "$dofid" ]; then
      add_node "dofini_$dofid" -subfile "dofini.sub"
      add_edge "dofini_$dofid" 'mkdirs'
      [ ! -f "$dofdir/$dofid$dofsuf" ] || node_done "dofini_$dofid"
    else
      for id in "${ids[@]}"; do
        add_node "dofini_$id" -subfile "dofini.sub" -var "id=\"$id\""
        add_edge "dofini_$id" 'mkdirs'
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
  local args w i j t s n lvl res blr is_done

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
  local ids=
  local imgdir=
  local imgpre=
  local imgsuf='.nii.gz'
  local domain=
  local model=
  local mffd='Sum'
  local similarity='NMI'
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
  local padding=
  local segdir=
  local segments=()
  local ic='false'
  local sym='false'
  local group=1
  local params=

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
      -subjects)
        optargs ids "$@"
        shift ${#ids[@]}; ;;
      -model)
        optarg model $1 "$2"
        shift; ;;
      -mffd)
        optarg mffd $1 "$2"
        shift; ;;
      -hdrdofs)
        optarg hdrdofs $1 "$2"
        shift; hdrdof_opt='-dof'; ;;
      -invhdrdofs)
        optarg hdrdofs $1 "$2"
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
      -mskdir)
        optarg segdir $1 "$2"
        shift; ;;
      -segmsk)
        local segment
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
      -bgvalue)
        optarg bgvalue $1 "$2"
        shift; ;;
      -padding)
        optarg padding $1 "$2"
        shift; ;;
      -interp)
        optarg interp $1 "$2"
        shift; ;;
      -maxres)
        optarg resolution $1 "$2"
        shift; ;;
      -levels)
        optargs levels "$@"
        if [ ${#levels[@]} -gt 2 ]; then
          error "register_node: too many arguments for option: $1"
        fi
        shift ${#levels[@]}
        if [ ${#levels[@]} -eq 1 ]; then
          levels=("${levels[0]}" 1)
        fi; ;;
      -inverse-consistent)
        ic='true'; ;;
      -symmetric)
        ic='true'; sym='true'; ;;
      -ds)
        optarg w $1 "$2"
        params="$params\nControl point spacing = $w"
        shift; ;;
      -be)
        optarg w $1 "$2"
        params="$params\nBending energy weight = $w"
        shift; ;;
      -vp)
        optarg w $1 "$2"
        params="$params\nVolume preservation weight = $w"
        shift; ;;
      -jl|-jac)
        optarg w $1 "$2"
        params="$params\nJacobian penalty weight = $w"
        shift; ;;
      -group)
        optarg group $1 "$2"
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
  [ ${#ids[@]} -ge 2 ] || [ ${#ids[@]} -gt 0 -a -n "$tgtid$srcid" ] || {
    error "register_node: not enough -subjects specified"
  }
  [ -n "$dofdir" ] || error "register_node: missing output -dofdir argument"
  [ -n "$tgtdir"                ] || tgtdir="$imgdir"
  [ -n "$tgtpre" -o -n "$tgtid" ] || tgtpre="$imgpre"
  [ -n "$tgtsuf"                ] || tgtsuf="$imgsuf"
  [ -n "$srcdir"                ] || srcdir="$imgdir"
  [ -n "$srcpre" -o -n "$srcid" ] || srcpre="$imgpre"
  [ -n "$srcsuf"                ] || srcsuf="$imgsuf"
  [ -z "$padding" ] || interp="$interp with padding"
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

  local nlevels=${levels[0]}
  if [ -n "$resolution" ]; then
    let nlevels="${levels[0]} - ${levels[1]} + 1"
    resolution=$('/usr/bin/bc' -l <<< "2^(${levels[1]}-1) * $resolution")
    resolution=$(remove_trailing_zeros $resolution)
    levels=($nlevels 1)
  fi

  local fidelity
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
  if [ -n "$dofid" ]; then
    N=1
  elif [ -n "$tgtid" -o -n "$srcid" ]; then
    N=${#ids[@]}
  else
    let N="${#ids[@]} * (${#ids[@]} - 1)"
    [ $ic = false ] || let N="$N / 2"
  fi

  # add SUBDAG node
  info "Adding node $node..."
  begin_dag $node -splice || {

    # registration parameters
    local cfg="[default]"
    cfg="$cfg\nTransformation model             = $model"
    cfg="$cfg\nMulti-level transformation       = $mffd"
    cfg="$cfg\nImage interpolation mode         = $interp"
    cfg="$cfg\nEnergy function                  = $fidelity + 0 BE[Bending energy](T) + 0 VP[Volume preservation](T) + 0 JAC[Jacobian penalty](T)"
    cfg="$cfg\nSimilarity measure               = $similarity"
    cfg="$cfg\nNo. of bins                      = 64"
    cfg="$cfg\nLocal window size [box]          = 5 vox"
    cfg="$cfg\nMaximum streak of rejected steps = 1"
    cfg="$cfg\nStrict step length range         = No"
    cfg="$cfg\nNo. of resolution levels         = $nlevels"
    cfg="$cfg\nFinal resolution level           = ${levels[1]}"
    if [ -n "$bgvalue" ]; then
      cfg="$cfg\nBackground value of image 1      = $bgvalue"
      cfg="$cfg\nBackground value of image 2      = $bgvalue"
    fi
    if [ -n "$padding" ]; then
      cfg="$cfg\nPadding value of image 1         = $padding"
      cfg="$cfg\nPadding value of image 2         = $padding"
    fi
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
        blr=(2 2) # blurring of binary mask
        if [ -n "$refid" -a -n "$refdir" ]; then
          blr[1]=1 # reference usually a probabilistic map (i.e., a bit blurry)
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

    # create generic register command script
    local sub="arguments    = \"-threads $threads"
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
      if [ "$dofins" = Id ]; then
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
      if [ "$dofins" = Id ]; then
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
      if [ "$dofins" = Id ]; then
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
      if [ "$dofins" = Id ]; then
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
    make_sub_script "register.sub" "$sub" -executable register

    # create generic dofinvert submission script
    if [ $ic = true ] && [ -z "$tgtid" -a -z "$srcid" ] ; then
      # command used to invert inverse-consistent transformation
      local sub="arguments    = \"'$dofdir/\$(target)/\$(source)$dofsuf' '$dofdir/\$(source)/\$(target)$dofsuf'\""
      sub="$sub\noutput       = $_dagdir/\$(target)/inv_\$(target),\$(source).log"
      sub="$sub\nerror        = $_dagdir/\$(target)/inv_\$(target),\$(source).log"
      sub="$sub\nqueue"
      make_sub_script "invert.sub" "$sub" -executable invert-dof
    fi

    # job to create output directories
    # better to have it done by a single script for all directories
    # than a PRE script for each registration job, which would require
    # the -maxpre option to avoid memory issues
    local pre=
    if [ -n "$tgtid" -o -n "$srcid" ]; then
      # directory for output files
      pre="$pre\nmkdir -p '$dofdir' || exit 1"
    else
      # directory for log files
      for id in "${ids[@]}"; do
        pre="$pre\nmkdir -p '$_dagdir/$id' || exit 1"
      done
      # directory for output files
      pre="$pre\n"
      for id in "${ids[@]}"; do
        pre="$pre\nmkdir -p '$dofdir/$id' || exit 1"
      done
    fi
    if [ -n "$pre" ]; then
      make_script "mkdirs.sh" "$pre"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
    fi

    # add node to register target to source
    if [ -n "$tgtid" -a -n "$srcid" ]; then
      n=1
      add_node "reg_$tgtid,$srcid" -subfile "register.sub"
      [ -z "$pre" ] || add_edge "reg_$tgtid,$srcid" 'mkdirs'
      [ ! -f "$dofdir/$dofid$dofsuf" ] || node_done "reg_$tgtid,$srcid"
    # add nodes to register subject images to common reference
    elif [ -n "$tgtid" ]; then
      if [ $group -gt 1 ]; then
        i=1
        while [ $i -le ${#ids[@]} ]; do
          let j=$i+$group-1
          add_node "reg_$i-$j" -subfile "register.sub" -grpvar 'source' -grpval "${ids[@]:$i-1:$group}"
          [ -z "$pre" ] || add_edge "reg_$i-$j" 'mkdirs'
          is_done='true'
          for id in ${ids[@]:$i:$group}; do
            if [ ! -f "$dofdir/$id$dofsuf" ]; then
              is_done='false'
              break
            fi
          done
          [ $is_done = false ] || node_done "reg_$i-$j"
          let i="$j+1"
        done
      else
        n=0
        for id in "${ids[@]}"; do
          let n++
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
          let j=$i+$group-1
          add_node "reg_$i-$j" -subfile "register.sub" -grpvar 'target' -grpval "${ids[@]:$i-1:$group}"
          [ -z "$pre" ] || add_edge "reg_$i-$j" 'mkdirs'
          is_done='true'
          for id in ${ids[@]:$i:$group}; do
            if [ ! -f "$dofdir/$id$dofsuf" ]; then
              is_done='false'
              break
            fi
          done
          [ $is_done = false ] || node_done "reg_$i-$j"
          let i="$j+1"
        done
      else
        n=0
        for id in "${ids[@]}"; do
          let n++
          add_node "reg_$id" -subfile "register.sub" -var "target=\"$id\""
          [ -z "$pre" ] || add_edge "reg_$id" 'mkdirs'
          [ ! -f "$dofdir/$id$dofsuf" ] || node_done "reg_$id"
        done
      fi
    # add pairwise registration nodes
    else
      n=0
      t=0
      local s1 s2 S grpids srcids
      for id1 in "${ids[@]}"; do
        let t++
        # register all other images to image of subject id1
        if [ $group -gt 1 ]; then
          s1=1
          if [ $ic = true ]; then
            let S="$t-1"
          else
            let S=${#ids[@]}
          fi
          i=0
          while [ $s1 -le $S ]; do
            s=$s1
            srcids=()
            let s2="$s1+$group-1"
            if [ $ic = true ]; then
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
              add_node "reg_$id1-$i" -subfile "register.sub" \
                                     -var     "target=\"$id1\"" \
                                     -grpvar  "source" \
                                     -grpval  "${srcids[@]}"
              add_edge "reg_$id1-$i" 'mkdirs'
              is_done='true'
              for id2 in ${srcids[@]}; do
                if [ ! -f "$dofdir/$id1/$id2$dofsuf" ]; then
                  is_done='false'
                  break
                fi
              done
              [ $is_done = false ] || node_done "reg_$id1-$i"
              # node to invert inverse-consistent transformation
              if [ $ic = true ] && [ -n "$dofdir" ]; then
                add_node "inv_$id1-$i" -subfile "invert.sub" \
                                       -var     "target=\"$id1\"" \
                                       -grpvar  "source" \
                                       -grpval  "${srcids[@]}"
                add_edge "inv_$id1-$i" "reg_$id1-$i"
                is_done='true'
                for id2 in ${srcids[@]}; do
                  if [ ! -f "$dofdir/$id2/$id1$dofsuf" ]; then
                    is_done='false'
                    break
                  fi
                done
                [ $is_done = false ] || node_done "inv_$id1-$i"
              fi
            fi
            let s1="$s2+1"
          done
        else
          s=0
          for id2 in "${ids[@]}"; do
            let s++
            if [ $ic = true ]; then
              [ $t -lt $s ] || continue
            else
              [ $t -ne $s ] || continue
            fi
            let n++
            # node to register id1 and id2
            add_node "reg_$id1,$id2" -subfile "register.sub" \
                                     -var     "target=\"$id1\"" \
                                     -var     "source=\"$id2\""
            add_edge "reg_$id1,$id2" 'mkdirs'
            [ ! -f "$dofdir/$id1/$id2$dofsuf" ] || node_done "reg_$id1,$id2"
            # node to invert inverse-consistent transformation
            if [ $ic = true ] && [ -n "$dofdir" ]; then
              add_node "inv_$id1,$id2" -subfile "invert.sub" \
                                       -var     "target=\"$id1\"" \
                                       -var     "source=\"$id2\""
              add_edge "inv_$id1,$id2" "reg_$id1,$id2"
              [ ! -f "$dofdir/$id2/$id1$dofsuf" ] || node_done "inv_$id1,$id2"
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
transform_image_node()
{
  local node=
  local parent=()
  local ids=
  local outdir=
  local ref=
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
  [ -n "$ref"        ] || error "transform_image_node: missing -ref argument"
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
    sub="$sub -dofin '$dofins/\$(target)/\$(source).dof.gz' -matchInputType -target '$ref' -$interp -threads $threads"
    sub="$sub\""
    sub="$sub\noutput       = $_dagdir/\$(target)/transform_\$(source).log"
    sub="$sub\nerror        = $_dagdir/\$(target)/transform_\$(source).log"
    sub="$sub\nqueue"
    make_sub_script "transform.sub" "$sub" -executable transform-image

    # create generic resample submission script
    if [ $resample = true ]; then
      sub="arguments    = \""
      sub="$sub '$prefix\$(id)$suffix'"
      sub="$sub '$outdir/\$(id)/\$(id)$suffix'"
      [ -z "$hdrdofs" ] || sub="$sub -dof '$hdrdofs/\$(id).dof.gz'"
      sub="$sub -dofin identity -matchInputType -target '$ref' -$interp -threads $threads"
      sub="$sub\""
      sub="$sub\noutput       = $_dagdir/\$(id)/resample.log"
      sub="$sub\nerror        = $_dagdir/\$(id)/resample.log"
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
      sub="$sub\noutput       = $_dagdir/\$(target)/postalign_\$(source).log"
      sub="$sub\nerror        = $_dagdir/\$(target)/postalign_\$(source).log"
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

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent) optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids "$@"; shift ${#ids[@]}; ;;
      -sublst) optarg idlst $1 "$2"; shift; ;;
      -dofins) optarg dofins $1 "$2"; shift; ;;
      -dofdir) optarg dofdir $1 "$2"; shift; ;;
      -dofsuf) optarg dofsuf $1 "$2"; shift; ;;
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
    make_script "mkdirs.sh" "mkdir -p '$dofdir' || exit 1"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.log\nqueue"

    # add invert-dof nodes to DAG
    for id in "${ids[@]}"; do
      add_node "invert_$id" -subfile "invert.sub" -var "id=\"$id\""
      add_edge "invert_$id" 'mkdirs'
      [ ! -f "$dofdir3/$id.dof.gz" ] || node_done "invert_$id"
    done

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
  local options='-v -all'

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
      -invert)        options="$options -invert";  ;;
      -inverse)       options="$options -inverse";  ;;
      -inverse-dofs)  options="$options -inverse-dofs";  ;;
      -norigid)       options="$options -norigid";  ;;
      -notranslation) options="$options -notranslation";  ;;
      -norotation)    options="$options -norotation";  ;;
      -noscaling)     options="$options -noscaling";  ;;
      -noshearing)    options="$options -noshearing";  ;;
      -dofs)          options="$options -dofs"; ;;
      -*)             error "average_dofs_node: invalid option: $1"; ;;
      *)              [ -z "$node" ] || error "average_dofs_node: too many arguments"
                      node=$1; ;;
    esac
    shift
  done
  [ -n "$node"   ] || error "average_dofs_node: missing name argument"
  [ -n "$dofins" ] || error "average_dofs_node: missing -dofins argument"

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
      sub="$sub'$dofdir/$dofid$dofsuf' $options -threads $threads"
      sub="$sub -dofdir '$dofins' -dofnames '$doflst' -prefix '$dofpre' -suffix '$dofsuf'"
      sub="$sub\""
      sub="$sub\noutput    = $_dagdir/dofavg_$dofid.log"
      sub="$sub\nerror     = $_dagdir/dofavg_$dofid.log"
    else
      [ -n "$dofpre" ] || dofpre='$(id)/'
      sub="$sub'$dofdir/\$(id)$dofsuf' $options -threads $threads -add-identity-for-dofname '\$(id)'"
      sub="$sub -dofdir '$dofins' -dofnames '$doflst' -prefix '$dofpre' -suffix '$dofsuf'"
      sub="$sub\""
      sub="$sub\noutput    = $_dagdir/dofavg_\$(id).log"
      sub="$sub\nerror     = $_dagdir/dofavg_\$(id).log"
    fi
    sub="$sub\nqueue"
    make_sub_script "dofavg.sub" "$sub" -executable average-dofs

    # node to create output directories
    if [ -n "$dofdir" ]; then
      make_script "mkdirs.sh" "mkdir -p '$dofdir' || exit 1"
      add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                        -sub        "error = $_dagdir/mkdirs.log\nqueue"
    fi

    # add dofaverage nodes to DAG
    if [ -n "$dofid" ]; then
      add_node "dofavg_$dofid" -subfile "dofavg.sub"
      add_edge "dofavg_$dofid" 'mkdirs'
      [ ! -f "$dofdir/$dofid$dofsuf" ] || node_done "dofavg_$dofid"
    else
      if [ ${#ids[@]} -eq 0 ]; then
        read_sublst ids "$doflst"
      fi
      for id in "${ids[@]}"; do
        add_node "dofavg_$id" -subfile "dofavg.sub" -var "id=\"$id\""
        add_edge "dofavg_$id" 'mkdirs'
        [ ! -f "$dofdir/$id$dofsuf" ] || node_done "dofavg_$id"
      done
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
  local dofdir1=
  local dofdir2=
  local dofdir3=
  local dofsuf='.dof.gz'

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids    "$@"; shift ${#ids[@]}; ;;
      -sublst)   optarg  idlst   $1 "$2"; shift; ;;
      -dofid)    optarg  dofid3  $1 "$2"; shift; ;;
      -dofid1)   optarg  dofid1  $1 "$2"; shift; ;;
      -dofid2)   optarg  dofid2  $1 "$2"; shift; ;;
      -dofid3)   optarg  dofid3  $1 "$2"; shift; ;;
      -dofdir)   optarg  dofdir  $1 "$2"; shift; ;;
      -dofdir1)  optarg  dofdir1 $1 "$2"; shift; ;;
      -dofdir2)  optarg  dofdir2 $1 "$2"; shift; ;;
      -dofdir3)  optarg  dofdir3 $1 "$2"; shift; ;;
      -dofsuf)   optarg  dofsuf  $1 "$2"; shift; ;;
      -*)        error "compose_dofs_node: invalid option: $1"; ;;
      *)         [ -z "$node" ] || error "compose_dofs_node: too many arguments"
                 node=$1; ;;
    esac
    shift
  done
  [ -n "$node" ] || error "compose_dofs_node: missing name argument"
  [ -n "$dofdir" ] || error "compose_dofs_node: missing output -dofdir argument"
  [ -n "$dofdir1" ] || error "compose_dofs_node: missing input -dofdir1 argument"
  [ -n "$dofdir2" ] || error "compose_dofs_node: missing input -dofdir2 argument"
  if [ -z "$dofid" ]; then
    dofid='$(id)'
    if [ ${#ids[@]} -eq 0 -a -z "$idlst" ]; then
      error "compose_dofs_node: missing -subjects or -sublst argument"
    fi
  elif [ ${#ids[@]} -gt 0 -o -n "$idlst" ]; then
    error "compose_dofs_node: options -dofid and -subjects/-sublst are mutually exclusive"
  fi
  [ -n "$dofid1" ] || dofid1="$dofid"
  [ -n "$dofid2" ] || dofid2="$dofid"
  [ -n "$dofid3" ] || dofid3="$dofid"

  info "Adding node $node..."
  begin_dag $node -splice || {

    # create generic dofcombine submission script
    local sub="arguments = \"'$dofdir1/$dofid1$dofsuf' '$dofdir2/$dofid2$dofsuf'"
    [ -z "$dofdir3" ] || sub="$sub '$dofdir3/$dofid3$dofsuf'"
    sub="$sub '$dofdir/$dofid$dofsuf' -threads $threads\""
    sub="$sub\noutput    = $_dagdir/compose_$dofid3.log"
    sub="$sub\nerror     = $_dagdir/compose_$dofid3.log"
    sub="$sub\nqueue"
    make_sub_script "compose.sub" "$sub" -executable compose-dofs

    # node to create output directories
    make_script "mkdirs.sh" "mkdir -p '$dofdir3' || exit 1"
    add_node "mkdirs" -executable "$topdir/$_dagdir/mkdirs.sh" \
                      -sub        "error = $_dagdir/mkdirs.log\nqueue"

    # add dofcombine nodes to DAG
    if [ "$dofid" = '$(id)' ]; then
      [ ${#ids[@]} -gt 0 ] || read_sublst ids "$idlst"
      for id in "${ids[@]}"; do
        add_node "compose_$id" -subfile "compose.sub" -var "id=\"$id\""
        add_edge "compose_$id" 'mkdirs'
        [ ! -f "$dofdir/$id$dofsuf" ] || node_done "compose_$id"
      done
    else
      add_node "compose_$dofid" -subfile "compose.sub"
      add_edge "compose_$dofid" 'mkdirs'
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
  local refdir=
  local refpre=
  local refid=
  local refsuf=
  local imgdir=
  local imgpre=
  local imgsuf='.nii.gz'
  local dofdir=
  local dofpre=
  local dofsuf='.dof.gz'
  local dofinv='false'
  local average=
  local options='-v'
  local label margin bgvalue

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)   optargs parent "$@"; shift ${#parent[@]}; ;;
      -subjects) optargs ids    "$@"; shift ${#ids[@]}; ;;
      -sublst)   optarg  idlst   $1 "$2"; shift; ;;
      -refdir)   optarg  refdir  $1 "$2"; shift; ;;
      -refpre)   refpre="$2"; shift; ;;
      -refid)    refid="$2"; shift; ;;
      -refsuf)   refsuf="$2"; shift; ;;
      -imgdir)   optarg  imgdir  $1 "$2"; shift; ;;
      -imgpre)   imgpre="$2"; shift; ;;
      -imgsuf)   optarg  imgsuf  $1 "$2"; shift; ;;
      -dofdir)   optarg  dofdir  $1 "$2"; shift; ;;
      -dofpre)   optarg  dofpre  $1 "$2"; shift; ;;
      -dofsuf)   optarg  dofsuf  $1 "$2"; shift; ;;
      -dofinv) options="$options -invert"; ;;
      -output)   optarg  average $1 "$2"; shift; ;;
      -voxelwise) options="$options -voxelwise"; ;;
      -voxelsize|-resolution)
        local voxelsize
        optargs voxelsize "$@"
        if [ ${#voxelsize[@]} -gt 3 ]; then
          error "average_images_node: too many -voxelsize, -resolution arguments"
        fi
        shift ${#voxelsize[@]}
        options="$options -size ${voxelsize[@]}"
        ;;
      -margin)   optarg  margin  $1 "$2"; shift; options="$options -margin $margin";;
      -bgvalue)  optarg  bgvalue $1 "$2"; shift; options="$options -padding $bgvalue";;
      -label)    optarg  label   $1 "$2"; shift; options="$options -label $label";;
      -*)        error "average_images_node: invalid option: $1"; ;;
      *)         [ -z "$node" ] || error "average_images_node: too many arguments"
                 node="$1"; ;;
    esac
    shift
  done
  [ -n "$node" ] || error "average_images_node: missing name argument"
  [ -n "$average" ] || error "average_images_node: missing -output argument"
  [ -z "$imgdir" ] || imgpre="$imgdir/$imgpre"
  [ -z "$dofdir" ] || dofpre="$dofdir/$dofpre"
  [ -n "$refdir" ] || refdir="$imgdir"
  [ -n "$refsuf" ] || refsuf="$imgsuf"
  [ -z "$refid" ] || options="$options -reference '$refdir/$refpre$refid$refsuf'"

  info "Adding node $node..."
  begin_dag $node -splice || {

    # write image list with optional transformations and weights
    local imglst="$_dagdir/images.csv"
    local images="$topdir\n"
    if [ -n "$idlst" ]; then
      [ ${#ids[@]} -eq 0 ] || error "average_images_node: options -subjects and -sublst are mutually exclusive"
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
    local sub="arguments = \"$average -images '$imglst'$options -threads $threads\""
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