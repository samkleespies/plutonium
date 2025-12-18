#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PACKAGE_NAME="helium-build-package.tar.gz"
OUTPUT_PATH="${ROOT_DIR}/${PACKAGE_NAME}"

echo "Creating transfer package for Ubuntu VM..."
echo "This will package the helium-build directory for transfer."
echo ""

cd "${ROOT_DIR}/.."

tar --exclude='helium-build/build' \
    --exclude='helium-build/.git' \
    --exclude='helium-build/helium-chromium/.git' \
    --exclude='*.o' \
    --exclude='*.a' \
    --exclude='*.profraw' \
    --exclude='*.profdata' \
    -czvf "${OUTPUT_PATH}" \
    helium-build/

echo ""
echo "Package created: ${OUTPUT_PATH}"
echo "Size: $(du -h "${OUTPUT_PATH}" | cut -f1)"
echo ""
echo "Transfer to your Ubuntu VM using:"
echo "  scp ${OUTPUT_PATH} user@vm-ip:~/"
echo ""
echo "On the VM, extract with:"
echo "  cd ~"
echo "  tar -xzvf ${PACKAGE_NAME}"
echo "  cd helium-build"
echo "  ./scripts/setup-build-env.sh"
echo "  ./scripts/build-optimized.sh --pgo-chromium"
