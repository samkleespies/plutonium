# Helium Mega-Optimized Build

This is a pre-configured build environment for Helium browser with all performance optimizations enabled, including support for custom PGO profiles.

## Performance Tiers

| Build Mode | Command | Performance | Build Time |
|------------|---------|-------------|------------|
| Standard | `--optimized` | ~80% of Chrome | 2-4 hours |
| Chromium PGO | `--pgo-chromium` | ~90% of Chrome | 3-5 hours |
| Custom PGO | `--pgo-custom` | ~95% of Chrome | 6-8 hours total |

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
v8_enable_maglev=true                 # Mid-tier JIT
v8_enable_turbofan=true               # Optimizing JIT
v8_enable_builtins_optimization=true  # PGO for V8
v8_enable_fast_torque=true
use_v8_context_snapshot=true
optimize_webui=true
```

### flags.linux.gn (Linux-Specific)
```gn
use_text_section_splitting=true       # Better cache locality
is_cfi=true                           # Control Flow Integrity
use_vaapi=true                        # Hardware video acceleration
rtc_use_pipewire=true                 # Modern screen sharing
ffmpeg_branding="Chrome"              # All codecs
proprietary_codecs=true
```

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
