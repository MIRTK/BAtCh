################################################################################
# Utilities for DAG generation
################################################################################

[ -z $__daggen_dag_sh ] || return 0
__daggen_dag_sh=0

# ------------------------------------------------------------------------------
# import modules
_moddir="$(dirname "$BASH_SOURCE")"
source "$_moddir/utils.sh" || {
  echo "Failed to import daggen/utils module!" 1>&2
  exit 1
}

# ==============================================================================
# auxiliary functions
# ==============================================================================

# ------------------------------------------------------------------------------
# copy executable and its dependencies
#
# TODO: Copy shared libraries (mainly MIRTK) to ensure libs and executables are
#       not modified during atlas construction via updated installation.
#       Mainly an issue for myself (Andreas) because of ongoing development.
pack_executable()
{
  if [ ! -f "$bindir/$1" ]; then
    local path="$(which "$1" 2> /dev/null)"
    if [ -n "$path" ]; then
      makedir "$bindir"
      if [ $binlnk = 'true' ]; then
        ln -s "$path" "$bindir/$1" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          info  "  Linked executable $path"
        else
          error "  Failed to link executable $path"
        fi
      else
        cp -f "$path" "$bindir/" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          info  "  Copied executable $path"
        else
          error "  Failed to copy executable $path"
        fi
      fi
    else
      error "  Could not find executable $1"
    fi
  fi
}

# ------------------------------------------------------------------------------
# write common configuration of HTCondor job description, i.e., universe,
# executable, environment, and requirements to new file
make_sub_script()
{
  local file=
  local subdesc=
  local universe=vanilla
  local executable=
  local _requirements="$requirements"
  local requirement

  while [ $# -gt 0 ]; do
    case "$1" in
      -universe)    optarg universe    $1 "$2"; shift; ;;
      -executable)  optarg executable  $1 "$2"; shift; ;;
      -requirement) optarg requirement $1 "$2"; shift;
                    [ -z "$_requirements" ] || _requirements="$_requirements && "
                    _requirements="$_requirements($requirement)"
                    ;;
      --) shift; break; ;;
      -*) error "make_sub_script: invalid option: $1"; ;;
      *)  if [ -z "$file" ]; then
            file="$1"
          else
            subdesc="$subdesc\n$1"
          fi
          ;;
    esac
    shift
  done
  [ -n "$file"       ] || error "make_sub_script: missing filename argument"
  [ -n "$executable" ] || error "make_sub_script: missing -executable argument"
  if [[ ${executable:0:1} != / ]]; then
    pack_executable "$executable"
    executable="$topdir/$bindir/$executable"
  fi
  makedir "$(dirname "$topdir/$_dagdir/$file")"
  cat --<<EOF > "$topdir/$_dagdir/$file"
universe     = $universe
environment  = "LD_LIBRARY_PATH='$topdir/$libdir:$LD_LIBRARY_PATH' PYTHONPATH='$PYTHONPATH'"
initialdir   = $topdir
executable   = $executable
log          = $topdir/$log
notify_user  = $notify_user
notification = $notification
requirements = $_requirements
EOF
  echo -en "$subdesc" >> "$topdir/$_dagdir/$file"
}

# ------------------------------------------------------------------------------
# write PRE/POST script of HTCondor DAGMan node
make_script()
{
  [ $# -ge 1 ] || error "make_script: invalid number of arguments"
  local file="$1"; shift
  makedir "$(dirname "$topdir/$_dagdir/$file")"
  cat --<<EOF > "$topdir/$_dagdir/$file"
#! /bin/bash
cd "$topdir" || exit 1
EOF
  chmod +x "$topdir/$_dagdir/$file" || exit 1
  while [ $# -gt 0 ]; do
    echo -ne "$1" >> "$topdir/$_dagdir/$file"
    shift
  done
}

# ------------------------------------------------------------------------------
# append rescue file with DONE nodes
node_done()
{
  append "$_rscfile" "DONE $_prefix$1\n"
}

# ==============================================================================
# DAG description
# ==============================================================================

_dagfiles=()
_dagfile=
_rscfiles=()
_rscfile=
_dagdirs=()
_dagdir=
_prefixes=()
_prefix=

# ------------------------------------------------------------------------------
## Begin DAG description
#
# @code
# begin_dag 'a_dag' || {
#   # add nodes here
# }; end_dag
# @endcode
#
# @returns whether new DAG file was started (1) or existing one kept (0).
begin_dag()
{
  [ -n "$_dagdir"  ] || _dagdir="$dagdir" # global dagdir set in config.sh

  local node=
  local parent=()
  local dagfile=
  local dagdir=
  local splice='false'

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)  optargs parent "$@"; shift ${#parent[@]}; ;;
      -dagfile) optarg dagfile $1 "$2"; shift; ;;
      -dagdir)  optarg dagdir  $1 "$2"; shift; ;;
      -splice)  splice='true';  ;;
      -subdag)  splice='false'; ;;
      -*)       error "begin_dag: invalid option: $1"; ;;
      *)        [ -z "$node" ] || error "begin_dag: too many arguments"
                node=$1; ;;
    esac
    shift
  done
  [ -n "$node"    ] || error "begin_dag: missing name argument"
  [ -n "$dagfile" ] || dagfile="$_dagdir/$node.dag"
  [ -n "$dagdir"  ] || dagdir="$_dagdir/$node"

  if [ -n "$_dagfile" ]; then
    # push parent DAG info on stack
    _dagfiles=("${_dagfiles[@]}" "${_dagfile}")
    _dagdirs=("${_dagdirs[@]}"   "${_dagdir}")
    _rscfiles=("${_rscfiles[@]}" "${_rscfile}")
    _prefixes=("${_prefixes[@]}"  "${_prefix}")
    # add SUBDAG/SPLICE to current (SUB)DAG/SPLICE
    if [[ $splice == true ]]; then
      append "$_dagfile" "\nSPLICE $node $topdir/$dagfile\n"
      _prefix="$_prefix$node+"
    else
      append "$_dagfile" "\nSUBDAG EXTERNAL $node $topdir/$dagfile\n"
      _prefix=
    fi
    add_edge $node ${parent[@]}
  fi
  # start new (SUB)DAG/SPLICE
  _dagfile="$dagfile"
  _dagdir="$dagdir"
  if [[ $update == true ]] || [ ! -f "$_dagfile" ]; then
    write "$_dagfile" "# HTCondor DAGMan description file generated by $appid\n"
    if [[ $splice == false ]] || [ -z "$_rscfile" ]; then
      rm -f "$_dagfile.rescue"???
      _rscfile="$_dagfile.rescue001"
      write "$_rscfile" "# HTCondor DAGMan rescue file generated by $appid\n"
    fi
    return 1
  else
    [[ $splice == true ]] || _rscfile="$_dagfile.rescue001"
    return 0
  fi
}

# ------------------------------------------------------------------------------
## Add directed flow edge to DAG
add_edge()
{
  [ $# -gt 0 ] || error "add_edge: invalid number of arguments"
  local child=$1
  shift
  [ $# -eq 0 ] || append "$_dagfile" "PARENT $@ CHILD $child\n"
}

# ------------------------------------------------------------------------------
## End DAG description
end_dag()
{
  [ $# -eq 0 ] || error "end_dag: invalid number of arguments"
  if [ ${#_dagfiles[@]} -gt 0 ]; then
    # pop parent DAG info from stack
    _dagfile="${_dagfiles[${#_dagfiles[@]}-1]}"
    _rscfile="${_rscfiles[${#_rscfiles[@]}-1]}"
    _dagdir="${_dagdirs[${#_dagdirs[@]}-1]}"
    _prefix="${_prefixes[${#_prefixes[@]}-1]}"
    unset _dagfiles[${#_dagfiles[@]}-1]
    unset _rscfiles[${#_rscfiles[@]}-1]
    unset _dagdirs[${#_dagdirs[@]}-1]
    unset _prefixes[${#_prefixes[@]}-1]
  else
    _dagfile=
    _dagdir=
    _rscfile=
    _prefix=
  fi
}

# ------------------------------------------------------------------------------
# write DAGMan node scripts
add_node()
{
  local name=$1; shift
  local predesc=
  local prefile=
  local subdesc=
  local subfile=
  local postdesc=
  local postfile=
  local executable=
  local var=
  local vars=
  local grpvar=
  local grpval=()
  local opt=
  local i

  while [ $# -gt 0 ]; do
    case "$1" in
      -executable) optarg  executable $1 "$2"; shift; ;;
      -pre)        optarg  predesc    $1 "$2"; shift; ;;
      -prefile)    optarg  prefile    $1 "$2"; shift; ;;
      -sub)        optarg  subdesc    $1 "$2"; shift; ;;
      -subfile)    optarg  subfile    $1 "$2"; shift; ;;
      -post)       optarg  postdesc   $1 "$2"; shift; ;;
      -postfile)   optarg  postfile   $1 "$2"; shift; ;;
      -var)        optarg  var        $1 "$2"; shift; vars="$vars $var"; ;;
      -grpvar)     optarg  grpvar     $1 "$2"; shift; ;;
      -grpval)     optargs grpval "$@"; shift ${#grpval[@]}; ;;
      *) error "add_node: invalid option or argument: $1"; ;;
    esac
    shift
  done
  [ -n "$name" ] || error "add_node: missing name argument"
  [ -z "$grpvar" ] || [ ${#grpval[@]} -gt 0 ] || error "add_node: missing values for group variable"
  # SUB description file
  if [ -n "$subfile" ]; then
    [ -z "$subdesc" ] || append "$topdir/$_dagdir/$subfile" "$subdesc"
  else
    [ -n "$executable" ] || error "add_node: missing -executable or -subfile"
    subfile=$name.sub
    make_sub_script "$subfile" "$subdesc" -executable "$executable"
  fi
  if [ -n "$grpvar" ]; then
    if [ ! -f "$topdir/$_dagdir/$subfile.${#grpval[@]}" ]; then
      append "$topdir/$_dagdir/$subfile.${#grpval[@]}" "$(awk '
      BEGIN { is_header = 1; }
      {
        if ($0 ~ /^arguments/) { is_header = 0; }
        if (is_header == 1) { print; }
      }' "$topdir/$_dagdir/$subfile")"
      i=1
      while [ $i -le ${#grpval[@]} ]; do
        append "$topdir/$_dagdir/$subfile.${#grpval[@]}" "\n\n$(awk '
        BEGIN { is_header = 1; }
        {
          if ($0 ~ /^arguments/) { is_header = 0; }
          if (is_header == 0) { print gensub(/\$\('$grpvar'\)/, "$('$grpvar$i')", "g"); }
        }' "$topdir/$_dagdir/$subfile")"
        let i++
      done
    fi
    subfile="$subfile.${#grpval[@]}"
  fi
  append "$_dagfile" "\nJOB $name $topdir/$_dagdir/$subfile\n"
  # VARS
  i=1
  while [ $i -le ${#grpval[@]} ]; do
    vars="$vars $grpvar$i=\"${grpval[$i-1]}\""
    let i++
  done
  [ -z "$vars" ] || append "$_dagfile" "VARS $name $vars\n"
  # PRE script (optional)
  if [ -n "$prefile" ]; then
    [ -z "$predesc" ] || append "$topdir/$_dagdir/$prefile" "$predesc"
    append "$_dagfile" "SCRIPT PRE $name $topdir/$_dagdir/$prefile\n"
  elif [ -n "$predesc" ]; then
    prefile=$name.pre
    make_script "$prefile" "$predesc"
    append "$_dagfile" "SCRIPT PRE $name $topdir/$_dagdir/$prefile\n"
  fi
  # POST script (optional)
  if [ -n "$postfile" ]; then
    [ -z "$postdesc" ] || append "$postfile" "$postdesc"
    append "$_dagfile" "SCRIPT POST $name $topdir/$_dagdir/$postfile\n"
  elif [ -n "$postdesc" ]; then
    postfile=$name.post
    make_script "$postfile" "$postdesc"
    append "$_dagfile" "SCRIPT POST $name $topdir/$_dagdir/$postfile\n"
  fi
}

# ------------------------------------------------------------------------------
# write DAGMan node scripts
add_group_node()
{
  local name=$1; shift
  local predesc=
  local prefile=
  local subdesc=
  local subfile=
  local postdesc=
  local postfile=
  local executable=
  local var=
  local vars=

  while [ $# -gt 0 ]; do
    case "$1" in
      -executable) optarg  executable $1 "$2"; shift; ;;
      -pre)        optarg  predesc    $1 "$2"; shift; ;;
      -prefile)    optarg  prefile    $1 "$2"; shift; ;;
      -sub)        optarg  subdesc    $1 "$2"; shift; ;;
      -subfile)    optarg  subfile    $1 "$2"; shift; ;;
      -post)       optarg  postdesc   $1 "$2"; shift; ;;
      -postfile)   optarg  postfile   $1 "$2"; shift; ;;
      -var)        optarg  var        $1 "$2"; shift; vars="$vars $var"; ;;
      *) error "add_node: invalid option or argument: $1"; ;;
    esac
    shift
  done
  [ -n "$name" ] || error "add_node: missing name argument"
  # SUB description file
  if [ -n "$subfile" ]; then
    [ -z "$subdesc" ] || append "$topdir/$_dagdir/$subfile" "$subdesc"
  else
    [ -n "$executable" ] || error "add_node: missing -executable or -subfile"
    subfile=$name.sub
    make_sub_script "$subfile" "$subdesc" -executable "$executable"
  fi
  append "$_dagfile" "\nJOB $name $topdir/$_dagdir/$subfile\n"
  # VARS
  [ -z "$vars" ] || append "$_dagfile" "VARS $name $vars\n"
  # PRE script (optional)
  if [ -n "$prefile" ]; then
    [ -z "$predesc" ] || append "$topdir/$_dagdir/$prefile" "$predesc"
    append "$_dagfile" "SCRIPT PRE $name $topdir/$_dagdir/$prefile\n"
  elif [ -n "$predesc" ]; then
    prefile=$name.pre
    make_script "$prefile" "$predesc"
    append "$_dagfile" "SCRIPT PRE $name $topdir/$_dagdir/$prefile\n"
  fi
  # POST script (optional)
  if [ -n "$postfile" ]; then
    [ -z "$postdesc" ] || append "$postfile" "$postdesc"
    append "$_dagfile" "SCRIPT POST $name $topdir/$_dagdir/$postfile\n"
  elif [ -n "$postdesc" ]; then
    postfile=$name.post
    make_script "$postfile" "$postdesc"
    append "$_dagfile" "SCRIPT POST $name $topdir/$_dagdir/$postfile\n"
  fi
}

# ------------------------------------------------------------------------------
# append DAGMan node scripts
append_node()
{
  local name=$1; shift
  local predesc=
  local prefile=$name.pre
  local subdesc=
  local subfile=$name.sub
  local postdesc=
  local postfile=$name.post

  while [ $# -gt 0 ]; do
    case "$1" in
      -pre)        optarg  predesc    $1 "$2"; shift; ;;
      -prefile)    optarg  prefile    $1 "$2"; shift; ;;
      -sub)        optarg  subdesc    $1 "$2"; shift; ;;
      -subfile)    optarg  subfile    $1 "$2"; shift; ;;
      -post)       optarg  postdesc   $1 "$2"; shift; ;;
      -postfile)   optarg  postfile   $1 "$2"; shift; ;;
      *) error "append_node: invalid option or argument: $1"; ;;
    esac
    shift
  done
  [ -n "$name" ] || error "append_node: missing name argument"

  [ -z "$subdesc"  ] || append "$topdir/$_dagdir/$subfile"  "$subdesc"
  [ -z "$predesc"  ] || append "$topdir/$_dagdir/$prefile"  "$predesc"
  [ -z "$postdesc" ] || append "$topdir/$_dagdir/$postfile" "$postdesc"
}
