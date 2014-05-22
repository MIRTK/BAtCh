################################################################################
#
################################################################################

[ -z $__daggen_core_sh ] || return 0
__daggen_core_sh=0

[ -n "$verbose" ] || verbose=0 # global verbosity level

# ------------------------------------------------------------------------------
# print message
info()  { [ $verbose -lt 1 ] || echo -e "$1"; }
warn()  { echo -e "$1" 1>&2; }
error() { warn "$1"; exit 1; }

# ------------------------------------------------------------------------------
# usage: foo () { local "$1" && upvar $1 "Hello, World!" }
upvar()
{
  if unset -v "$1"; then       # unset & validate varname
    if (( $# == 2 )); then
      eval $1=\"\$2\"          # return single value
    else
      eval $1=\(\"\${@:2}\"\)  # return array
    fi
  fi
}

# ------------------------------------------------------------------------------
# get command-line option argument
optarg()
{
  [ -n "$3" ] || { echo "Option $2 requires an argument!" 1>&2; exit 1; }
  local "$1" && upvar $1 "$3"
}

# ------------------------------------------------------------------------------
# get command-line option arguments
optargs()
{
  local var="$1"
  local opt="$2"
  local arg=()
  shift 2
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) break; ;;
      *)  arg=("${arg[@]}" "$1"); ;;
    esac
    shift
  done
  [ ${#arg[@]} -gt 0 ] || { echo "Option $opt requires an argument!" 1>&2; exit 1; }
  local "$var" && upvar $var "${arg[@]}"
}
