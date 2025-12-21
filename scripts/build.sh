#!/bin/bash
set -euo pipefail

clone=false
with_pgo=false
clean=false

while [ $# -gt 0 ]; do
    case "$1" in
        -c) clone=true; shift;;
        --pgo) with_pgo=true; shift;;
        --clean) clean=true; shift;;
    esac
done

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/shared.sh"

setup_environment

if [ "$clean" = true ]; then
    # clean out/ directory before build
    rm -rf "${_src_dir}/out" || true
fi

fetch_sources "$clone" "$with_pgo"
apply_patches
apply_domsub
helium_substitution
helium_version
helium_resources
write_gn_args
fix_tool_downloading
setup_toolchain
gn_gen
build
