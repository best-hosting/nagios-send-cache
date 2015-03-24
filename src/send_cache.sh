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

cache=''
fresh=0
plugin=''
# I rely below, that initial values are $ret_unkn and empty $res .
ret="$ret_unkn"
res=''

usage()
{
    echo "Usage: $(basename $0) [--cache path] [--fresh minutes] [plugin which cache to read]"
}

# Send results. Uses global variables $ret and $res .
send()
{
    echo "${res:-Output was empty..}"
    exit $ret
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
        cache="$2"
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
cache="${cache:-${plugin:+$(basename "$plugin").cache}}"
if [ -z "$cache" ]; then
    ret=$ret_unkn
    res="No cache file specified, $(usage)"
    send
fi
# Default cache directory, if path is relative.
if [ "${cache#.}" != "$cache" ]; then
    cache="$(pwd)/$cache"
elif [ "${cache#/}" = "$cache" ]; then
    cache="/var/cache/nagios3/$cache"
fi
readonly cache
IFS="$nl"
set -- $fresh
if [ $# -gt 1 ] || echo "$fresh" | grep -q -e '[^0-9]'; then
    ret=$ret_unkn
    res="Incorrect fresh interval '$fresh'."
    send
fi
IFS="$OIFS"
readonly fresh

if [ ! -r "$cache" ]; then
    ret=$ret_unkn
    res="Can't read cache '$cache'."
elif [ "$fresh" -gt 0 -a -z "$(find "$cache" -mmin -"$fresh")" ];
then
    ret=$ret_unkn
    res="Cache '$cache' is older, than '$fresh' minutes ago."
else
    ret="$(head -n 1 "$cache")"
    if [ "$ret" != "$ret_ok" \
        -a "$ret" != "$ret_warn" \
        -a "$ret" != "$ret_crit" \
        -a "$ret" != "$ret_unkn" ];
    then
        res="Unexpected plugin exit code '$ret'"
        ret=$ret_unkn
    fi
    res="${res:+$res, }$(tail -n '+2' "$cache")"
fi
send

