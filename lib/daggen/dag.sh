################################################################################
#
################################################################################

[ -z $__daggen_dag_sh ] || __daggen_dag_sh=0

# ------------------------------------------------------------------------------
# import modules
_moddir="$(dirname "$BASH_SOURCE")"
. "$_moddir/core.sh" || { echo "Failed to import daggen/core module!" 1>&2; exit 1; }
. "$_moddir/path.sh" || { echo "Failed to import daggen/path module!" 1>&2; exit 1; }

# ==============================================================================
# auxiliary functions
# ==============================================================================

# ------------------------------------------------------------------------------
# copy executable and its dependencies
pack_executable()
{
  if [ ! -f "$bindir/$1" ]; then
    local path="$(which "$1" 2> /dev/null)"
    if [ -n "$path" ]; then
      makedir "$bindir"
      cp -f "$path" "$bindir/" > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        info  "  Copied executable $path"
      else
        error "  Failed to copy executable $path"
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
  while [ $# -gt 0 ]; do
    case "$1" in
      -universe)   optarg universe   $1 "$2"; shift; ;;
      -executable) optarg executable $1 "$2"; shift; ;;
      --)          shift; break; ;;
      -*)          error "make_sub_script: invalid option: $1"; ;;
      *)           if [ -z "$file" ]; then
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
  makedir "$(dirname "$topdir/$_dagdir")"
  cat --<<EOF > "$topdir/$_dagdir/$file"
universe     = $universe
environment  = LD_LIBRARY_PATH=$topdir/$libdir:$LD_LIBRARY_PATH
initialdir   = $topdir
executable   = $executable
log          = $topdir/$log
notify_user  = $notify_user
notification = $notification
requirements = $requirements
EOF
  echo -en "$subdesc" >> "$topdir/$_dagdir/$file"
}

# ------------------------------------------------------------------------------
# write PRE/POST script of HTCondor DAGMan node
make_script()
{
  [ $# -ge 1 ] || error "make_script: invalid number of arguments"
  local file="$1"; shift
  makedir "$topdir/$_dagdir"
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

# ==============================================================================
# DAG description
# ==============================================================================

_dagfiles=()
_dagfile=
_dagdirs=()
_dagdir=

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

  while [ $# -gt 0 ]; do
    case "$1" in
      -parent)  optargs parent "$@"; shift ${#parent[@]}; ;;
      -dagfile) optarg dagfile $1 "$2"; shift; ;;
      -dagdir)  optarg dagdir  $1 "$2"; shift; ;;
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
    # add SUBDAG node to current (SUB)DAG
    append "$_dagfile" "\nSUBDAG EXTERNAL $node $topdir/$dagfile\n"
    add_edge $node ${parent[@]}
    # push parent DAG info on stack
    _dagfiles=("${_dagfiles[@]}" "${_dagfile}")
    _dagdirs=("${_dagdirs[@]}"   "${_dagdir}")
  fi
  # start new (SUB)DAG
  _dagfile="$dagfile"
  _dagdir="$dagdir"
  if [[ $update == true ]] || [ ! -f "$dagfile" ]; then
    write "$dagfile" "# HTCondor DAGMan description file generated by\n# $appdir/$appname\n"
    return 1
  else
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
    _dagdir="${_dagdirs[${#_dagdirs[@]}-1]}"
    unset _dagfiles[${#_dagfiles[@]}-1]
    unset _dagdirs[${#_dagdirs[@]}-1]
  else
    _dagfile=
    _dagdir=
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
