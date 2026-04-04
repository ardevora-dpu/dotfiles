#!/usr/bin/env bash

set -euo pipefail

path="${1:-}"
path="${path%/}"

if [[ -z "$path" ]]; then
    printf '%s\n' "shell"
    exit 0
fi

if [[ "$path" == "/" ]]; then
    printf '%s\n' "/"
    exit 0
fi

label="${path##*/}"

if [[ "$path" =~ /quinlan(/|$) ]]; then
    label="main"
elif [[ "$path" =~ /(quinlan-[^/]+)(/|$) ]]; then
    label="${BASH_REMATCH[1]#quinlan-}"
elif [[ -z "$label" ]]; then
    label="shell"
fi

printf '%s\n' "$label"
