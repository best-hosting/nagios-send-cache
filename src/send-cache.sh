#!/bin/sh

set -euf

# Args:
# 1 - cache file path.
# 2 - cache expiration time.

# Cache:
# Line 1 is return code.
# All following lines are plugin stdout.

cache_file="$1"
if [ -r "$cache_file" ]; then
    ret="$(head -1 "$cache_file")"
    out="$(tail -n '+2' "$cache_file")"
else
    ret=3
    out="$(basename "$0"): Cache is empty."
fi
echo "$out"
exit $ret

