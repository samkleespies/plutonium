#!/bin/bash
#
# Helium Mega-Optimized Build Script
# Supports: Standard build, PGO with Chromium profiles, Custom PGO profiles
#
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default options
BUILD_MODE="optimized"  # optimized, pgo-chromium, pgo-custom, instrument
CLEAN_BUILD=false
JOBS=""
USE_CCACHE=true

show_help() {
    cat << EOF
Helium Mega-Optimized Build Script

USAGE:
    $0 [OPTIONS]

BUILD MODES:
    --optimized         Build with ThinLTO + V8 optimizations (default)
    --pgo-chromium      Build with Chromium's official PGO profiles (recommended)
    --pgo-custom        Build with your custom PGO profile
    --instrument        Build instrumented version for PGO profile generation

OPTIONS:
    --clean             Clean build directory before building
    --jobs N            Number of parallel jobs (default: auto)
    --no-ccache         Disable ccache/sccache
    --help              Show this help message

RECOMMENDED BUILD ORDER FOR CUSTOM PGO:
    1. $0 --instrument
    2. Run the browser, use it normally for 30+ minutes
    3. $0 --generate-profile
    4. $0 --pgo-custom

EXAMPLES:
    # Standard optimized build (no PGO)
    $0 --optimized

    # Best performance with Chromium's PGO profiles
    $0 --pgo-chromium

    # Build for generating your own PGO profile
    $0 --instrument
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --optimized)
            BUILD_MODE="optimized"
            shift
            ;;
        --pgo-chromium)
            BUILD_MODE="pgo-chromium"
            shift
            ;;
        --pgo-custom)
            BUILD_MODE="pgo-custom"
            shift
            ;;
        --instrument)
            BUILD_MODE="instrument"
            shift
            ;;
        --generate-profile)
            BUILD_MODE="generate-profile"
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --jobs)
            JOBS="$2"
            shift 2
            ;;
        --no-ccache)
            USE_CCACHE=false
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
source "${SCRIPT_DIR}/shared.sh"

setup_environment

# Paths
FLAGS_GN="${_main_repo}/flags.gn"
FLAGS_LINUX_GN="${ROOT_DIR}/flags.linux.gn"
PROFILE_DATA="${ROOT_DIR}/build/pgo-profile.profdata"
PROFILE_RAW_DIR="${ROOT_DIR}/build/pgo-raw"

print_status "Build mode: ${BUILD_MODE}"
print_status "Root directory: ${ROOT_DIR}"

# Clean if requested
if [ "$CLEAN_BUILD" = true ]; then
    print_status "Cleaning build directory..."
    rm -rf "${_src_dir}/out" || true
    rm -f "${_src_dir}/.downloaded.stamp" "${_src_dir}/.patched.stamp" "${_src_dir}/.domsub.stamp" || true
fi

# Configure PGO phase based on build mode
configure_pgo() {
    local pgo_phase="$1"
    print_status "Setting chrome_pgo_phase=${pgo_phase}"
    
    # Update flags.gn with correct PGO phase
    sed -i "s/^chrome_pgo_phase=.*/chrome_pgo_phase=${pgo_phase}/" "${FLAGS_GN}"
}

# Add custom PGO profile path to args.gn
add_custom_pgo_path() {
    if [ -f "${PROFILE_DATA}" ]; then
        print_status "Using custom PGO profile: ${PROFILE_DATA}"
        # Will be added after gn gen
    else
        print_error "Custom PGO profile not found at ${PROFILE_DATA}"
        print_error "Run '$0 --instrument' first, then generate a profile"
        exit 1
    fi
}

case $BUILD_MODE in
    optimized)
        print_status "Building with ThinLTO + V8 optimizations (no PGO)"
        configure_pgo 0
        
        fetch_sources false false
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
        
        print_success "Optimized build complete!"
        print_status "Binary at: ${_out_dir}/chrome"
        ;;
        
    pgo-chromium)
        print_status "Building with Chromium's official PGO profiles"
        configure_pgo 0  # Will be set to 2 by fetch_sources with pgo
        
        fetch_sources true true  # clone=true, with_pgo=true
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
        
        print_success "PGO-optimized build complete!"
        print_status "Binary at: ${_out_dir}/chrome"
        ;;
        
    pgo-custom)
        print_status "Building with custom PGO profile"
        
        if [ ! -f "${PROFILE_DATA}" ]; then
            print_error "Custom profile not found at: ${PROFILE_DATA}"
            print_error "First run: $0 --instrument"
            print_error "Then run the browser and generate profile"
            print_error "Then run: $0 --generate-profile"
            exit 1
        fi
        
        configure_pgo 2
        
        fetch_sources true false  # clone=true, no chromium pgo
        apply_patches
        apply_domsub
        helium_substitution
        helium_version
        helium_resources
        write_gn_args
        
        # Add custom profile path
        echo "pgo_data_path = \"${PROFILE_DATA}\"" >> "${_out_dir}/args.gn"
        
        fix_tool_downloading
        setup_toolchain
        gn_gen
        build
        
        print_success "Custom PGO build complete!"
        print_status "Binary at: ${_out_dir}/chrome"
        ;;
        
    instrument)
        print_status "Building instrumented version for PGO profile generation"
        configure_pgo 1
        
        fetch_sources true false  # Must use clone for PGO
        apply_patches
        apply_domsub
        helium_substitution
        helium_version
        helium_resources
        write_gn_args
        
        # Ensure PGO phase 1 is set
        echo "chrome_pgo_phase = 1" >> "${_out_dir}/args.gn"
        
        fix_tool_downloading
        setup_toolchain
        gn_gen
        build
        
        print_success "Instrumented build complete!"
        print_status "Binary at: ${_out_dir}/chrome"
        echo ""
        print_status "NEXT STEPS:"
        echo "  1. Run the browser with your typical usage pattern:"
        echo "     ${_out_dir}/chrome --user-data-dir=/tmp/helium-pgo-profile"
        echo ""
        echo "  2. Use it for 30+ minutes - browse, scroll, watch videos"
        echo ""
        echo "  3. Close the browser and generate profile:"
        echo "     $0 --generate-profile"
        echo ""
        echo "  4. Build the optimized version:"
        echo "     $0 --pgo-custom"
        ;;
        
    generate-profile)
        print_status "Generating PGO profile from raw data..."
        
        mkdir -p "${PROFILE_RAW_DIR}"
        mkdir -p "$(dirname "${PROFILE_DATA}")"
        
        # Find all .profraw files
        PROFRAW_FILES=$(find "${_out_dir}" -name "*.profraw" 2>/dev/null || true)
        
        if [ -z "$PROFRAW_FILES" ]; then
            print_error "No .profraw files found in ${_out_dir}"
            print_error "Make sure you ran the instrumented browser first"
            exit 1
        fi
        
        print_status "Found profile data files:"
        echo "$PROFRAW_FILES"
        
        # Merge profiles
        LLVM_PROFDATA="${_src_dir}/third_party/llvm-build/Release+Asserts/bin/llvm-profdata"
        
        if [ ! -f "$LLVM_PROFDATA" ]; then
            print_error "llvm-profdata not found. Run instrument build first."
            exit 1
        fi
        
        print_status "Merging profile data..."
        $LLVM_PROFDATA merge \
            -output="${PROFILE_DATA}" \
            ${PROFRAW_FILES}
        
        print_success "Profile generated at: ${PROFILE_DATA}"
        echo ""
        print_status "NEXT STEP:"
        echo "  Build the optimized version:"
        echo "  $0 --pgo-custom"
        ;;
        
    *)
        print_error "Unknown build mode: ${BUILD_MODE}"
        exit 1
        ;;
esac
