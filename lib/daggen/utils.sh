################################################################################
# Auxiliary functions for Bash scripting
################################################################################

[ -z $__daggen_utils_sh ] || return 0
__daggen_utils_sh=0

[ -n "$verbose" ] || verbose=0 # global verbosity level

# ------------------------------------------------------------------------------
# print message
info()
{
  [ $verbose -lt 1 ] || echo -e "$1"
}

warn()
{
  echo -e "$1" 1>&2
}

error()
{
  local frame=0
  while caller $frame; do
    ((frame++));
  done
  warn "$*"
  exit 1
}

# ------------------------------------------------------------------------------
# remove trailing zeros from floating point number (e.g., returned by bc)
remove_trailing_zeros()
{
  echo -n $1 | sed 's/\(\.[0-9]*[1-9]\)0*$/\1/;s/\.0*$//'
}

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
  [ -n "$3" ] || error "Option $2 requires an argument!"
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
  [ ${#arg[@]} -gt 0 ] || error "Option $opt requires an argument!"
  local "$var" && upvar $var "${arg[@]}"
}

# ------------------------------------------------------------------------------
# join two paths if the second path is not absolute
joinpaths()
{
  if [[ ${2:0:1} == '/' ]]; then echo -n "$2"
                            else echo -n "$1/$2"
  fi
}

# ------------------------------------------------------------------------------
# make directory or exit on failure
makedir()
{
  mkdir -p "$1" > /dev/null
  local rc=$?
  if [ $rc -ne 0 ]; then
    error "Failed to create directory \"$1\"!"
  fi
  return $rc
}

# ------------------------------------------------------------------------------
# write string to specified text file
write()
{
  makedir "$(dirname "$1")"
  echo -ne "$2" > "$1"
}

# ------------------------------------------------------------------------------
# append string to specified text file
append()
{
  makedir "$(dirname "$1")"
  echo -ne "$2" >> "$1"
}

# ------------------------------------------------------------------------------
# read subject IDs from text file (first column)
read_sublst()
{
  local ids=($(cat "$2" | tr '\t' ',' | tr ' ' ',' | tr '#' ',' | cut -d, -f1))
  [ ${#ids[@]} -gt 0 ] || error "Failed to read subject IDs from file $2"
  local "$1" && upvar $1 ${ids[@]}
}
