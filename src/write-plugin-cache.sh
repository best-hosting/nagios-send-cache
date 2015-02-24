#!/bin/sh

# Usage: $0 [--cache path] [plugin to execute with args..]

set -euf

readonly True=1
readonly False=0
readonly nl='
'

# Nagios return codes.
readonly ret_unkn=3
readonly ret_crit=2
readonly ret_warn=1
readonly ret_ok=0

plugin=''
ret="$ret_ok"
res=''

error()
{
    local OIFS="$IFS"
    IFS=','
    echo "Error: $(basename $0): $*" 1>&2
    IFS="$OIFS"
}
usage()
{
    echo "Usage: $(basename $0) [--cache path] [plugin to execute with args..]" 1>&2
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi
# All options must be before non-option arguments. Use '--' to terminate
# option list explicitly.
while [ $# -gt 0 ]; do
    case "$1" in
      '--help' )
	usage
	exit 1
      ;;
      '--cache' )
	if [ -z "${2:-}" ]; then
	    error "Cache file path can't be empty."
	    exit 1
	fi
	cache_file="$2"
	shift 2
      ;;
      '--' )
	shift
	break
      ;;
      * )
	if [ -z "${1:-}" ]; then
	    error "Plugin path can't be empty."
	    exit 1
	fi
	plugin="$1"
	shift
	break
    esac
done
readonly plugin


### Check args.
cache_file="${cache_file:-${plugin:+$(basename "$plugin").cache}}"
# Default cache directory, if path is relative.
if [ "${cache_file#.}" != "$cache_file" ]; then
    cache_file="$(pwd)/$cache_file"
elif [ "${cache_file#/}" = "$cache_file" ]; then
    cache_file="/var/cache/nagios3/$cache_file"
fi
readonly cache_file

if [ ! -d "$(dirname "$cache_file")" ]; then
    error "Cache directory $(dirname "$cache_file") does not exist."
    exit 1
fi


### Main.

# `type` can't handle only relative path without leading dot. But i don't want
# to handle it at all.
if type "$plugin" >/dev/null 2>&1; then
    res="$("$plugin" "$@" 2>&1)" || ret="$?"
else
    ret="$ret_unkn"
    res="Can't execute plugin '$plugin'"
fi

{
    if [ "$ret" = "$ret_ok" ]; then
	res="${res:-OK}"
    elif [ "$ret" = "$ret_warn" ]; then
	res="${res:-Some warning..}"
    elif [ "$ret" = "$ret_crit" ]; then
	res="${res:-Some critical..}"
    elif [ "$ret" = "$ret_unkn" ]; then
	res="${res:-Some unknown..}"
    else
	res="${res:+Unexpected plugin exit code '$ret'$nl$res}"
	res="${res:-Unexpected plugin exit code '$ret'}"
	ret="$ret_unkn"
    fi
    echo "$ret"
    echo "$res" | paste -d, -s
} > "$cache_file"

