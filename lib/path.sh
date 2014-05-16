###############################################################################
# 
###############################################################################

[ -z "$__path_sh" ] || __path_sh=0

# -----------------------------------------------------------------------------
# import modules
_moddir="`dirname "$BASH_SOURCE"`"
. "$_moddir/core.sh" || { echo "Failed to import core module!" 1>&2; exit 1; }

# -----------------------------------------------------------------------------
# join two paths if the second path is not absolute
joinpaths()
{
  if [[ ${2:0:1} == '/' ]]; then echo -n "$2"
                            else echo -n "$1/$2"
  fi
}

# -----------------------------------------------------------------------------
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
