#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_status "Setting up Helium build environment on Ubuntu..."

if [ "$(id -u)" = "0" ]; then
    print_error "Don't run this as root. It will use sudo when needed."
    exit 1
fi

print_status "Updating package lists..."
sudo apt-get update

print_status "Installing build dependencies..."
sudo apt-get install -y \
    build-essential \
    clang \
    lld \
    cmake \
    ninja-build \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    wget \
    pkg-config \
    libglib2.0-dev \
    libgtk-3-dev \
    libdrm-dev \
    libnss3-dev \
    libxss-dev \
    libxkbcommon-dev \
    libxcomposite-dev \
    libxdamage-dev \
    libxrandr-dev \
    libgbm-dev \
    libpango1.0-dev \
    libcairo2-dev \
    libasound2-dev \
    libpulse-dev \
    libcups2-dev \
    libdbus-1-dev \
    libudev-dev \
    libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    libsecret-1-dev \
    libnotify-dev \
    libva-dev \
    libpipewire-0.3-dev \
    ccache \
    nodejs \
    npm \
    gperf \
    bison \
    flex \
    quilt

print_status "Installing Python dependencies..."
pip3 install --user httplib2 six

print_status "Setting up ccache..."
ccache --max-size=50G
echo 'export PATH="/usr/lib/ccache:$PATH"' >> ~/.bashrc

print_status "Checking available resources..."
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)

echo ""
print_status "System resources:"
echo "  RAM: ${TOTAL_MEM}GB"
echo "  CPU cores: ${CPU_CORES}"
echo ""

if [ "$TOTAL_MEM" -lt 16 ]; then
    print_warning "Less than 16GB RAM detected."
    print_warning "Consider adding swap space or using fewer parallel jobs."
    echo ""
    
    SWAP_SIZE=$((32 - TOTAL_MEM))
    read -p "Create ${SWAP_SIZE}GB swap file? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Creating ${SWAP_SIZE}GB swap file..."
        sudo fallocate -l ${SWAP_SIZE}G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        print_success "Swap file created and enabled"
    fi
fi

RECOMMENDED_JOBS=$((CPU_CORES > 4 ? CPU_CORES - 2 : CPU_CORES))
if [ "$TOTAL_MEM" -lt 32 ]; then
    RECOMMENDED_JOBS=$((TOTAL_MEM / 4))
    [ "$RECOMMENDED_JOBS" -lt 2 ] && RECOMMENDED_JOBS=2
fi

print_success "Build environment setup complete!"
echo ""
print_status "Recommended ninja jobs: ${RECOMMENDED_JOBS}"
echo ""
print_status "Next steps:"
echo "  1. Source your updated bashrc: source ~/.bashrc"
echo "  2. Navigate to helium-build directory"
echo "  3. Run: ./scripts/build-optimized.sh --pgo-chromium"
echo ""
print_status "For custom PGO (maximum performance):"
echo "  1. ./scripts/build-optimized.sh --instrument"
echo "  2. Run the browser with your typical usage for 30+ mins"
echo "  3. ./scripts/build-optimized.sh --generate-profile"
echo "  4. ./scripts/build-optimized.sh --pgo-custom"
