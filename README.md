# Plutonium Browser

A performance-optimized, privacy-focused Chromium fork with auto-hiding toolbar functionality.

## Project Lineage

```
Chromium 143.0.7499.146 → ungoogled-chromium → Helium → Plutonium
```

## Key Features

- **Privacy-focused**: Based on ungoogled-chromium with Google services removed
- **Performance-optimized**: ThinLTO, PGO, AVX2 SIMD, V8 optimizations
- **Auto-hiding toolbar**: Immersive mode that hides toolbar until mouse hovers at top edge (IN DEVELOPMENT)
- **Clean UI**: Neutral gray color palette, minimal branding

## Repository Structure

```
plutonium/
├── README.md                    # This file
├── CLAUDE.md                    # Detailed technical documentation for AI agents
├── flags.linux.gn               # Linux-specific GN build args (AVX2, performance flags)
├── helium-chromium/             # Upstream Helium submodule
│   ├── flags.gn                 # Base GN args shared with Helium
│   └── patches/                 # Helium core patches
├── patches/
│   ├── series                   # Patch application order
│   ├── helium/linux/            # Plutonium-specific patches
│   │   ├── immersive-mode-linux.patch    # Auto-hiding toolbar (partial)
│   │   ├── plutonium-optimizations.patch # Compiler optimizations
│   │   ├── chrome-default-colors.patch   # Gray UI theme
│   │   └── ...
│   └── ungoogled-chromium/      # Upstream ungoogled patches
├── scripts/
│   ├── build.sh                 # Main build driver
│   ├── build-optimized.sh       # High-level build flow
│   ├── setup-build-env.sh       # VM dependency installer
│   ├── shared.sh                # Shared build functions
│   └── package.sh               # Packaging helper
└── build/                       # Build output directory (on VM)
```

## Build Environment

### VM Setup (Ubuntu on VirtualBox)

| Component | Specification |
|-----------|--------------|
| Host | Windows PC, 8 cores/16 threads, 32GB RAM |
| VM | Ubuntu, 14 vCPUs, 26GB RAM |
| Nested Virt | Enabled |
| Network | NAT with port forward 2222 → 22 |

### SSH Access

```bash
# VM (Ubuntu build environment)
ssh samkl@192.168.0.189 -p 2222

# Host Windows PC
ssh samkl@192.168.0.189
```

### Build Directory on VM

```
~/plutonium/
├── build/
│   └── src/
│       ├── out/Default/          # Build output
│       │   ├── chrome            # Main binary (~425MB)
│       │   ├── *.pak             # Resource files
│       │   ├── *.so              # Shared libraries
│       │   └── locales/          # Locale files
│       └── chrome/browser/ui/... # Source modifications
```

## Quick Start

### Building

```bash
# On the Ubuntu build VM
cd ~/plutonium
./scripts/build.sh -c --clean

# If you want to keep the Windows host responsive, cap build parallelism:
./scripts/build.sh --jobs 4 --load-average 4

# Or for optimized build
./scripts/build-optimized.sh --pgo-chromium
```

### Monitoring Build

```bash
# Check progress
ssh samkl@192.168.0.189 -p 2222 "ps aux | grep ninja | grep -v grep"

# Watch build output
ssh samkl@192.168.0.189 -p 2222 "tail -f ~/plutonium-build.log"
```

### Incremental Rebuild

```bash
# Most common: just rerun the main script (it skips download/patch steps via stamps)
cd ~/plutonium
./scripts/build.sh

# Or rebuild directly inside the Chromium checkout:
cd ~/plutonium/build/src
export PATH=~/depot_tools:$PATH
autoninja -C out/Default chrome -j 4 -l 4
```

## Local Installation

### Install Location

```
~/.local/share/plutonium-browser/
├── chrome                    # Main binary
├── chrome_crashpad_handler   # Crash handler
├── chrome_100_percent.pak    # UI resources (REQUIRED for icons)
├── chrome_200_percent.pak    # HiDPI resources
├── resources.pak             # General resources
├── icudtl.dat               # ICU data
├── v8_context_snapshot.bin  # V8 snapshot
├── lib*.so                  # Shared libraries
└── locales/                 # Locale files
```

### Copying Build from VM

```bash
# Copy essential files
scp -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/chrome ~/.local/share/plutonium-browser/
scp -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/chrome_*.pak ~/.local/share/plutonium-browser/
scp -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/{icudtl.dat,resources.pak,v8_context_snapshot.bin} ~/.local/share/plutonium-browser/
scp -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/lib*.so ~/.local/share/plutonium-browser/
scp -r -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/locales ~/.local/share/plutonium-browser/
```

### Running

```bash
~/.local/share/plutonium-browser/chrome
```

## Performance Optimizations

| Optimization | Description |
|-------------|-------------|
| ThinLTO | Link-time optimization for cross-module inlining |
| PGO | Profile-guided optimization using Chromium profiles |
| AVX2 | 256-bit SIMD for Haswell+ CPUs |
| V8 Tiers | Sparkplug, Maglev, TurboFan JIT compilers |
| VA-API | Hardware video acceleration |
| GPU Raster | GPU-accelerated page rendering |

## Current Development: Immersive Mode

Auto-hiding toolbar feature is in active development. See `CLAUDE.md` for technical details.

## License

- Chromium: BSD-3-Clause
- ungoogled-chromium additions: BSD-3-Clause
- Plutonium additions: BSD-3-Clause

See `LICENSE` and `LICENSE.ungoogled_chromium` for full text.
