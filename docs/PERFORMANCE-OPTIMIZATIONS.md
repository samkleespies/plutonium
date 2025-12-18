# Plutonium Browser Performance Optimizations

This document explains the performance optimization architecture for Plutonium browser builds. It is intended for developers and AI agents working on this codebase.

## Overview

This repository builds Plutonium browser (a Chromium fork) with Thorium-style performance optimizations. The goal is to achieve performance parity with Chrome Dev (~98-100%) while maintaining privacy features.

## Architecture

```
plutonium/
├── flags.linux.gn              # Linux-specific GN build flags
├── helium-chromium/
│   └── flags.gn                # Base GN build flags (all platforms)
├── patches/
│   ├── series                  # Patch application order
│   └── helium/linux/
│       ├── compiler-optimizations.patch  # -O3, LLVM opts
│       ├── avx2-optimizations.patch      # CPU SIMD targeting
│       ├── scrolling-performance.patch   # GPU raster, smooth scroll
│       ├── disable-status-bubble.patch   # Remove URL hover bubble
│       └── chrome-default-colors.patch   # Chrome gray color scheme
├── scripts/
│   ├── build-optimized.sh      # Main build script with PGO support
│   └── shared.sh               # Shared build functions
└── README-OPTIMIZED-BUILD.md   # User-facing documentation
```

## Key Files and Their Purpose

### 1. `flags.linux.gn` - Linux Build Configuration

**Location**: `/flags.linux.gn`

**Purpose**: Defines Linux-specific GN arguments merged with `helium-chromium/flags.gn` during build.

**Key optimizations**:
```gn
# Linker
use_lld=true              # LLVM linker (faster linking)
use_icf=true              # Identical Code Folding (smaller binary)

# CPU targeting
use_sse3=true
use_sse41=true
use_sse42=true
use_avx=true              # Enabled by default
# use_avx2=true           # Optional - uncomment for Haswell+ CPUs

# Security + Performance
is_cfi=true               # Control Flow Integrity
use_text_section_splitting=true  # Better cache locality
```

**When to modify**: 
- To change CPU targeting (enable/disable AVX2)
- To add Linux-specific compiler flags
- To change linker behavior

### 2. `helium-chromium/flags.gn` - Base Build Configuration

**Location**: `/helium-chromium/flags.gn`

**Purpose**: Platform-agnostic GN arguments. Contains V8 and core optimizations.

**Key optimizations**:
```gn
# LTO
use_thin_lto=true
thin_lto_enable_optimizations=true  # Critical: enables aggressive LTO

# V8 JIT tiers (all enabled for best JS performance)
v8_enable_sparkplug=true    # Baseline JIT
v8_enable_maglev=true       # Mid-tier JIT  
v8_enable_turbofan=true     # Optimizing JIT
v8_enable_builtins_optimization=true  # PGO for V8 builtins

# WebAssembly
v8_enable_webassembly=true
v8_enable_wasm_simd256_revec=true
v8_enable_wasm_code_cache=true

# PGO
chrome_pgo_phase=0  # Set to 2 for PGO builds (handled by build script)
```

**When to modify**:
- To change V8/JavaScript optimizations
- To change LTO settings
- To modify cross-platform build options

### 3. `patches/helium/linux/compiler-optimizations.patch`

**Purpose**: Modifies Chromium's `build/config/compiler/BUILD.gn` to add Thorium-style compiler optimizations.

**What it does**:
1. Changes optimization level from `-O2` to `-O3` for official builds
2. Adds LLVM loop optimization flags:
   - `-mllvm -aggressive-ext-opt` (aggressive extension optimization)
   - `-mllvm -enable-gvn-hoist` (Global Value Numbering hoisting)
3. Increases ThinLTO `import_instr_limit` from 30 to 100 (more aggressive inlining)
4. Adds linker optimization `-Wl,-O3`

**Performance impact**: ~3-5% improvement

**When to modify**:
- To change compiler optimization flags
- To adjust LTO inlining thresholds
- To add new LLVM optimization passes

### 4. `patches/helium/linux/avx2-optimizations.patch`

**Purpose**: Adds GN arguments and compiler flags for CPU SIMD instruction targeting.

**What it does**:
1. Declares GN args: `use_sse3`, `use_sse41`, `use_sse42`, `use_avx`, `use_avx2`
2. When enabled, adds corresponding compiler flags:
   - AVX: `-mavx -mpclmul -maes`
   - AVX2: `-mavx2 -mfma -mf16c -mlzcnt -mbmi2 -ffp-contract=fast`

**CPU Compatibility**:
| Flag | Minimum CPU |
|------|-------------|
| `use_sse42=true` | Intel Nehalem (2008), AMD Bulldozer (2011) |
| `use_avx=true` | Intel Sandy Bridge (2011), AMD Bulldozer (2011) |
| `use_avx2=true` | Intel Haswell (2013), AMD Zen (2017) |

**Performance impact**: AVX +1-2%, AVX2 +2-3% additional

**When to modify**:
- To add new CPU instruction set support (e.g., AVX-512)
- To change tuning targets (`-mtune=`)
- To add platform-specific SIMD flags

### 5. `patches/helium/linux/scrolling-performance.patch`

**Purpose**: Adds GN arguments for GPU rasterization and smooth scrolling optimizations.

**What it does**:
1. Enables GPU rasterization by default
2. Uses 4 raster threads for parallel compositing
3. Enables zero-copy GPU memory buffers
4. Enables top controls compositor animations

**Key GN flags added**:
```gn
enable_gpu_rasterization=true
num_raster_threads=4
enable_zero_copy=true
top_controls_show_threshold=0.5
top_controls_hide_threshold=0.5
```

**Performance impact**: Noticeably smoother scrolling, reduced scroll jank

### 6. `patches/helium/linux/disable-status-bubble.patch`

**Purpose**: Removes the URL status bubble that appears when hovering over links.

**What it does**:
- Adds early return in `StatusBubbleViews::SetURL()` to prevent bubble display
- Browser still functions normally, just no hover URL preview

**When to modify**:
- If you want to re-enable status bubble (remove the early return)
- If upstream changes `StatusBubbleViews` API

### 7. `patches/helium/linux/chrome-default-colors.patch`

**Purpose**: Reverts Helium's blue color scheme to Chrome's original gray colors.

**What it does**:
- Sets frame color to Chrome's gray (`#dee1e6`)
- Sets active tab background to white
- Sets toolbar color to light gray
- Removes blue tint from UI elements

**When to modify**:
- To customize the color scheme
- To adjust specific color values

### 9. `patches/series` - Patch Order

**Purpose**: Defines the order patches are applied to Chromium source.

**Current order**:
```
# Performance patches (early, before other compiler changes)
helium/linux/avx2-optimizations.patch
helium/linux/compiler-optimizations.patch
helium/linux/scrolling-performance.patch

# UI customizations
helium/linux/disable-status-bubble.patch
helium/linux/chrome-default-colors.patch

# Branding and other patches follow...
```

**Important**: Performance patches should be applied early to ensure they're not overwritten by other patches modifying `BUILD.gn`.

### 10. `scripts/build-optimized.sh` - Build Script

**Purpose**: Main build entry point with PGO support.

**Build modes**:
| Mode | Flag | Description |
|------|------|-------------|
| Optimized | `--optimized` | ThinLTO + V8 opts, no PGO |
| Chromium PGO | `--pgo-chromium` | Uses Google's PGO profiles |
| Custom PGO | `--pgo-custom` | Uses your custom profile |
| Instrument | `--instrument` | Builds instrumented binary for profiling |

**PGO workflow**:
```bash
# 1. Build instrumented
./scripts/build-optimized.sh --instrument

# 2. Run browser, generate profile data
./build/src/out/Default/chrome --user-data-dir=/tmp/pgo

# 3. Merge profile data
./scripts/build-optimized.sh --generate-profile

# 4. Build optimized with custom profile
./scripts/build-optimized.sh --pgo-custom
```

## How Optimizations Are Applied

### Build Flow

```
1. fetch_sources()     → Downloads Chromium source
2. apply_patches()     → Applies patches from patches/series
                         (includes compiler-optimizations.patch, avx2-optimizations.patch)
3. write_gn_args()     → Merges flags.gn + flags.linux.gn → out/Default/args.gn
4. gn_gen()            → Generates ninja build files
5. build()             → ninja builds chrome binary
```

### GN Argument Merge Order

```
helium-chromium/flags.gn    (base config)
    ↓
flags.linux.gn              (platform overrides)
    ↓
target_cpu, chrome_pgo_phase (build script additions)
    ↓
out/Default/args.gn         (final config)
```

## Performance Tuning Guide

### For Maximum Performance

1. Enable AVX2 (if CPU supports):
   ```gn
   # In flags.linux.gn
   use_avx2=true
   ```

2. Use custom PGO profile:
   ```bash
   ./scripts/build-optimized.sh --pgo-custom
   ```

3. Consider `-march=native` for single-machine builds (not portable):
   ```gn
   # In avx2-optimizations.patch, add:
   cflags += [ "-march=native" ]
   ```

### For Maximum Compatibility

1. Disable AVX (falls back to SSE4.2):
   ```gn
   # In flags.linux.gn
   use_avx=false
   ```

2. Use Chromium PGO (works on all x86-64):
   ```bash
   ./scripts/build-optimized.sh --pgo-chromium
   ```

## Adding New Optimizations

### To add a new compiler flag:

1. **If it's a GN argument** (like `use_avx2`):
   - Add declaration in `avx2-optimizations.patch` under `declare_args()`
   - Add flag logic in the `config("compiler")` section
   - Expose in `flags.linux.gn` with default value

2. **If it's a hardcoded optimization**:
   - Add to `compiler-optimizations.patch` in the appropriate section
   - Document in this file

### To add a new patch:

1. Create patch file in `patches/helium/linux/`
2. Add to `patches/series` in appropriate order
3. Test with clean build: `./scripts/build-optimized.sh --clean --optimized`

## Troubleshooting

### Patch fails to apply
- Check if Chromium version changed the target file
- Update line numbers in patch
- Use `patch -p1 --dry-run < patch.patch` to test

### Build fails with "unknown argument"
- GN argument may not exist in this Chromium version
- Check `gn args --list out/Default` for valid arguments

### Binary crashes on older CPU
- AVX2 enabled but CPU doesn't support it
- Set `use_avx2=false` in `flags.linux.gn`

### LTO linking runs out of memory
- Reduce parallel jobs: `ninja -j4`
- Add swap space
- Set `thin_lto_enable_cache=true` for incremental builds

## Performance Benchmarks

Expected Speedometer 2.1 scores relative to Chrome Dev:

| Configuration | Performance |
|---------------|-------------|
| Stock Chromium | ~75-80% |
| + ThinLTO + V8 opts | ~85-90% |
| + Chromium PGO | ~92-95% |
| + Custom PGO | ~95-98% |
| + AVX2 | ~98-100% |

## References

- [Thorium Browser](https://github.com/AleX313031/thorium) - Source of many optimizations
- [Chromium GN Build Configuration](https://www.chromium.org/developers/gn-build-configuration/)
- [V8 Performance](https://v8.dev/blog)
- [ThinLTO Documentation](https://clang.llvm.org/docs/ThinLTO.html)
