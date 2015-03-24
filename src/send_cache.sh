#!/bin/sh

# Usage: $0 [--cache path] [--fresh minutes] [plugin which cache to read]
# If both --cache option and plugin specified, option will take precedence.

set -euf

readonly True=1
readonly False=0
readonly nl='
'
readonly OIFS="$IFS"

# Nagios return codes.
readonly ret_unkn=3
readonly ret_crit=2
readonly ret_warn=1
readonly ret_ok=0

# Cache:
# Line 1 is return code.
# All following lines are plugin stdout.

cache_file=''
fresh=0
plugin=''
# I rely below, that initial values are $ret_unkn and empty $res .
ret="$ret_unkn"
res=''

usage()
{
    echo "Usage: $(basename $0) [--cache path] [--fresh minutes] [plugin which cache to read]"
}

# All options must be before non-option arguments. Use '--' to terminate
# option list explicitly.
while [ $# -gt 0 ]; do
    case "$1" in
      '--help' )
        usage 1>&2
        exit $ret_unkn
      ;;
      '--cache' )
        cache_file="$2"
        shift 2
      ;;
      '--fresh' )
        fresh="$2"
        shift 2
      ;;
      '--' )
        shift
        break
      ;;
      * )
        plugin="$1"
        shift
        break
    esac
done
readonly plugin

### Check args.
cache_file="${cache_file:-${plugin:+$(basename "$plugin").cache}}"
if [ -z "$cache_file" ]; then
    ret=$ret_unkn
    res="No cache file specified, $(usage)"
fi
# Default cache directory, if path is relative.
if [ "${cache_file#.}" != "$cache_file" ]; then
    cache_file="$(pwd)/$cache_file"
elif [ "${cache_file#/}" = "$cache_file" ]; then
    cache_file="/var/cache/nagios3/$cache_file"
fi
readonly cache_file
IFS="$nl"
set -- $fresh
if [ $# -gt 1 ] || echo "$fresh" | grep -q -e '[^0-9]'; then
    ret=$ret_unkn
    res="Incorrect fresh interval '$fresh'."
fi
IFS="$OIFS"
readonly fresh

# Assume, that initial result is empty. And if result is still empty, no
# errors was found so far.
if [ -z "$res" ]; then
    if [ ! -r "$cache_file" ]; then
        ret=$ret_unkn
        res="Can't read cache '$cache_file'."
    elif [ "$fresh" -gt 0 -a -z "$(find "$cache_file" -mmin -"$fresh")" ];
    then
        ret=$ret_unkn
        res="Cache '$cache_file' is older, than '$fresh' minutes ago."
    else
        ret="$(head -c 1 "$cache_file")"
        if [ "$ret" != "$ret_ok" \
            -a "$ret" != "$ret_warn" \
            -a "$ret" != "$ret_crit" \
            -a "$ret" != "$ret_unkn" ];
        then
            res="Unexpected plugin exit code '$ret'"
            ret=$ret_unkn
        fi
        res="${res:+$res, }$(tail -n '+2' "$cache_file")"
    fi
fi

echo "${res:-Output was empty..}"
exit $ret

