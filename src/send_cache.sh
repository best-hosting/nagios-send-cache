#!/bin/sh

# Usage: $0 [--cache path] [--fresh minutes] [plugin which cache to read] [plugin args..]
# If both --cache option and plugin specified, option will take precedence.
# If cache has modified more, than fresh minutes ago, and plugin name is
# specified (not empty), i'll try to run write-plugin-cache with that plugin
# name (and its arguments, if any was passed to send-cache). Then either
# result of write-plugin-cache (in case of error) or new (or old, if cache
# wasn't updated) cache content will be returned.

set -euf

readonly True=1
readonly False=0
readonly nl='
'
OIFS="$IFS"

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
plugin_has_run=$False
# I rely below, that initial values are $ret_unkn and empty $res .
ret="$ret_unkn"
res=''

# All functions below work with global variables!

usage()
{
    echo "Usage: $(basename $0) [--cache path] [--fresh minutes] [plugin which cache to read] [plugin args..]"
}

# Send results. Uses global variables $ret and $res .
send()
{
    echo "${res:-Output was empty..}"
    exit $ret
}

# Check arguments. I need to do this in separate function, so i may use
# positional parameters in some checks.
check_args()
{
    local OIFS="$IFS"

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
}

# Read and send cache file content. Args:
# 1.. - plugin args, if any. If $plugin name is empty and cache is out of
#   date, i won't run $plugin .  I don't check nothing before running plugin
#   here and rely on write-plugin-cache to do proper checking.
send_cache()
{
    local t=0

    if [ ! -r "$cache" ]; then
        ret=$ret_unkn
        res="Can't read cache '$cache'."
    else
        ret="$(head -n 1 "$cache")"
        if [ "$ret" != "$ret_ok" \
            -a "$ret" != "$ret_warn" \
            -a "$ret" != "$ret_crit" \
            -a "$ret" != "$ret_unkn" ];
        then
            res="Unexpected plugin exit code '$ret'"
            ret=$ret_unkn
        elif [ "$fresh" -gt 0 -a -z "$(find "$cache" -mmin -"$fresh")" ];
        then
            if [ "$plugin_has_run" = $False -a -n "$plugin" ]; then
                plugin_has_run=$True
                res="$(write-plugin-cache --cache "$cache" \
                                            "$plugin" "$@" 2>&1)" \
                        || t=$?
                if [ $t = 0 ]; then
                    ret=$ret_unkn
                    send_cache "$@"
                else
                    res="Plugin re-run returned '$res' and exited with '$t'"
                fi
            else
                res="Cache '$cache' is older, than '$fresh' minutes ago"
            fi
            if [ "$ret" = "$ret_ok" ]; then
                ret=$ret_warn
            fi
        fi
        res="${res:+$res, }$(tail -n '+2' "$cache")"
    fi
    send
}

# All options must be before non-option arguments. Use '--' to terminate
# option list explicitly. I need to parse options in main, so only plugin
# arguments remain in main's positional parameters.
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

# But i need to check args in separate function, so i may use positional
# parameters in some checks there.
check_args
send_cache "$@"

