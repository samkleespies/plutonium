# Plutonium - Maximum Performance Build

This is a pre-configured build environment for Plutonium browser with all performance optimizations enabled, including Thorium-style compiler optimizations and support for custom PGO profiles.

## Performance Tiers

| Build Mode | Command | Performance vs Chrome Dev | Build Time |
|------------|---------|---------------------------|------------|
| Standard | `--optimized` | ~85-90% | 2-4 hours |
| Chromium PGO | `--pgo-chromium` | ~92-95% | 3-5 hours |
| Custom PGO | `--pgo-custom` | ~96-98% | 6-8 hours total |
| Custom PGO + AVX2 | `--pgo-custom` (with `use_avx2=true`) | ~98-100% | 6-8 hours total |

## What's New (Thorium-Style Optimizations)

This build includes performance optimizations inspired by [Thorium Browser](https://thorium.rocks/):

### Compiler Optimizations (`compiler-optimizations.patch`)
- **-O3 optimization level** instead of -O2 (more aggressive optimizations)
- **LLVM loop optimizations**: `-mllvm -aggressive-ext-opt -mllvm -enable-gvn-hoist`
- **Increased ThinLTO inlining**: `import_instr_limit=100` (vs default 30)
- **Linker optimizations**: `-Wl,-O3`

### CPU Targeting (`avx2-optimizations.patch`)
- **AVX support** for Sandy Bridge+ CPUs (2011+)
- **AVX2 support** for Haswell+ CPUs (2013+) - optional, ~3-5% extra performance
- **AES-NI and PCLMUL** for hardware-accelerated encryption
- **FMA instructions** for faster floating-point math (AVX2 only)

### V8 JavaScript Engine
- **Sparkplug** baseline JIT compiler
- **Maglev** mid-tier JIT compiler
- **TurboFan** optimizing JIT compiler
- **WebAssembly SIMD256** optimizations
- **WebAssembly code caching**

## Quick Start (Ubuntu VM)

### Step 1: Transfer to VM

On your current machine:
```bash
cd ~/workspace/helium-build
./scripts/create-transfer-package.sh
scp helium-build-package.tar.gz user@your-vm-ip:~/
```

### Step 2: Setup VM Environment

On your Ubuntu VM:
```bash
cd ~
tar -xzvf helium-build-package.tar.gz
cd helium-build
./scripts/setup-build-env.sh
source ~/.bashrc
```

### Step 3: Build

For best balance of performance vs build time:
```bash
./scripts/build-optimized.sh --pgo-chromium
```

For maximum performance (custom PGO):
```bash
# Phase 1: Build instrumented version (~3 hours)
./scripts/build-optimized.sh --instrument

# Phase 2: Generate profile (30+ minutes of browsing)
./build/src/out/Default/chrome --user-data-dir=/tmp/helium-pgo

# Phase 3: Create profile data
./scripts/build-optimized.sh --generate-profile

# Phase 4: Build optimized version (~3 hours)
./scripts/build-optimized.sh --pgo-custom
```

## VM Requirements

### Minimum
- Ubuntu 22.04 or newer
- 16GB RAM (32GB recommended)
- 100GB free disk space
- 4 CPU cores

### Recommended (for fast builds)
- 32GB+ RAM
- 200GB SSD
- 8+ CPU cores
- If less than 32GB RAM, the setup script can create swap

### VM-Specific Tips

**VMware/VirtualBox:**
- Allocate at least 16GB RAM to the VM
- Use a fixed-size virtual disk (faster than dynamic)
- Enable nested virtualization if available
- Use SSD storage for the VM disk

**WSL2:**
- Edit `.wslconfig` in Windows user directory:
```ini
[wsl2]
memory=24GB
swap=16GB
processors=8
```
- Restart WSL: `wsl --shutdown`

**Hyper-V:**
- Use Dynamic Memory with minimum 16GB
- Enable all processor features
- Use fixed VHDX for better I/O

## Build Options

```bash
./scripts/build-optimized.sh [OPTIONS]

Build Modes:
  --optimized       ThinLTO + V8 optimizations, no PGO (fastest build)
  --pgo-chromium    Use Chromium's official PGO profiles (recommended)
  --pgo-custom      Use your custom PGO profile (maximum performance)
  --instrument      Build instrumented version for profile generation

Options:
  --clean           Clean build directory before building
  --jobs N          Override number of parallel jobs
  --no-ccache       Disable ccache
  --help            Show help
```

## What's Optimized

### flags.gn (Base Configuration)
```gn
is_official_build=true
use_thin_lto=true
thin_lto_enable_optimizations=true    # KEY: Enables -Wl,--lto-O2

# V8 JavaScript Engine (all JIT tiers enabled)
v8_enable_sparkplug=true              # Baseline JIT
v8_enable_maglev=true                 # Mid-tier JIT
v8_enable_turbofan=true               # Optimizing JIT
v8_enable_builtins_optimization=true  # PGO for V8
v8_enable_fast_torque=true
use_v8_context_snapshot=true

# WebAssembly
v8_enable_webassembly=true
v8_enable_wasm_simd256_revec=true     # 256-bit SIMD
v8_enable_wasm_code_cache=true        # Faster subsequent loads

optimize_webui=true
```

### flags.linux.gn (Linux-Specific)
```gn
# Linker optimizations
use_lld=true                          # LLVM linker (faster)
use_icf=true                          # Identical Code Folding
use_text_section_splitting=true       # Better cache locality
is_cfi=true                           # Control Flow Integrity

# CPU targeting (enabled by default)
use_sse3=true
use_sse41=true
use_sse42=true
use_avx=true
# use_avx2=true                       # Uncomment for Haswell+ CPUs

# Media
use_vaapi=true                        # Hardware video acceleration
rtc_use_pipewire=true                 # Modern screen sharing
ffmpeg_branding="Chrome"              # All codecs
proprietary_codecs=true
```

### Compiler Patches (Applied Automatically)
```
patches/helium/linux/compiler-optimizations.patch
  - -O3 optimization level
  - LLVM loop optimizations
  - import_instr_limit=100 for aggressive inlining

patches/helium/linux/avx2-optimizations.patch
  - AVX/AVX2/FMA instruction targeting
  - AES-NI hardware encryption
  - Fast FP contraction
```

## AVX2 Build (Maximum Performance)

If your CPU supports AVX2 (Intel Haswell 2013+, AMD Zen 2017+), you can enable additional optimizations for ~3-5% extra performance.

### Check if your CPU supports AVX2:
```bash
grep -o 'avx2' /proc/cpuinfo | head -1
# If it outputs "avx2", your CPU supports it
```

### Enable AVX2:
Edit `flags.linux.gn` and uncomment the AVX2 line:
```gn
use_avx2=true
```

Then build normally. The resulting binary will be ~3-5% faster but will **NOT run** on CPUs without AVX2 support.

### AVX2 Build Optimizations Include:
- 256-bit integer SIMD operations (`-mavx2`)
- Fused multiply-add instructions (`-mfma`)
- Half-precision float conversion (`-mf16c`)
- Bit manipulation instructions (`-mbmi2`, `-mlzcnt`)
- Fast floating-point contraction (`-ffp-contract=fast`)

---

## Custom PGO Profile Tips

For the best custom profile:

1. **Browse your typical sites** - News, social media, YouTube, etc.
2. **Scroll extensively** - This optimizes the compositor and rendering
3. **Watch videos** - Optimizes media playback paths
4. **Use web apps** - Gmail, Google Docs, etc.
5. **Open many tabs** - Tests memory management paths
6. **Keep browsing for 30+ minutes** - More data = better optimization

The profile captures hot code paths specific to YOUR usage patterns.

## Troubleshooting

### Out of Memory During Build
```bash
# Reduce parallel jobs
export NINJA_JOBS=4
./scripts/build-optimized.sh --pgo-chromium

# Or add more swap
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### LTO Link Phase Hangs
LTO linking is memory-intensive. If it hangs:
```bash
# Add to flags.linux.gn:
# thin_lto_cache_policy="cache_size=10%"
```

### Build Fails After Partial Completion
```bash
./scripts/build-optimized.sh --clean --pgo-chromium
```

### No .profraw Files Generated
Ensure you built with `--instrument` and ran the browser long enough. Check:
```bash
find build/src/out/Default -name "*.profraw"
```

## Output

After successful build:
```
build/src/out/Default/chrome          # The browser binary
build/src/out/Default/chromedriver    # For automation
```

## Transferring Built Binary Back

```bash
# On VM, create package
tar -czvf helium-optimized.tar.gz \
    build/src/out/Default/chrome \
    build/src/out/Default/chrome_crashpad_handler \
    build/src/out/Default/*.so \
    build/src/out/Default/locales \
    build/src/out/Default/resources.pak \
    build/src/out/Default/icudtl.dat \
    build/src/out/Default/v8_context_snapshot.bin

# Transfer back to your main machine
scp helium-optimized.tar.gz user@main-machine:~/
```

## Expected Build Times

| Hardware | --optimized | --pgo-chromium | --pgo-custom (total) |
|----------|-------------|----------------|---------------------|
| 8-core, 32GB RAM | ~2.5h | ~3.5h | ~6h |
| 16-core, 64GB RAM | ~1.5h | ~2h | ~4h |
| 32-core, 128GB RAM | ~45m | ~1h | ~2h |

Build time scales roughly linearly with CPU cores, but RAM can become a bottleneck during LTO linking.

## Performance Impact Breakdown

| Optimization | Speedometer Gain | Binary Size |
|--------------|------------------|-------------|
| ThinLTO + Official Build | Baseline | Baseline |
| + PGO (Chromium profiles) | +10-15% | +0% |
| + -O3 (vs -O2) | +2-3% | +5-10% |
| + LLVM loop opts | +1-2% | +1% |
| + import_instr_limit=100 | +0.5-1% | +1% |
| + AVX (vs SSE4.2) | +1-2% | +0% |
| + AVX2 (vs AVX) | +2-3% | +0% |
| + Custom PGO profile | +2-5% | +0% |
| **Total Potential Gain** | **~20-30%** | **~7-12%** |

## Remaining Gap vs Chrome Dev

Even with all optimizations, there may be a small gap (~2-5%) compared to Chrome Dev due to:

1. **Google's internal PGO profiles** - Based on telemetry from billions of users
2. **Proprietary optimizations** - Some Chrome-specific code paths not in Chromium
3. **Testing infrastructure** - Google can test/tune on more hardware configurations

To close the remaining gap:
- Generate custom PGO profiles with YOUR browsing patterns
- If your CPU supports AVX2, enable it
- Consider building with `-march=native` for your specific CPU (not portable)
