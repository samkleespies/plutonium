# Plutonium Browser

## Summary
- Performance-optimized, privacy-focused Chromium fork.
- Lineage: Chromium 143.0.7499.146 -> ungoogled-chromium -> Helium -> Plutonium.
- Target: Chrome Dev performance on Ryzen 7 7800X3D (AVX2 enabled).

## Repository Layout
```
plutonium/
├── flags.linux.gn              # Linux GN args (AVX2 enabled here)
├── helium-chromium/flags.gn    # Base GN args shared with Helium
├── patches/series              # Patch order
├── patches/helium/linux/       # Performance and UI patches
├── scripts/                    # Build tooling
└── README.md                   # Consolidated documentation
```

## Build Scripts
- `scripts/build.sh`: main VM build driver; supports `-c` (clone), `--pgo`, and `--clean` (wipe `out/`).
- `scripts/build-optimized.sh`: higher-level flow with `--optimized`, `--pgo-chromium`, `--pgo-custom`.
- `scripts/setup-build-env.sh`: installs deps for Ubuntu VM.
- `scripts/create-transfer-package.sh`: bundles repo for transfer to VM.
- `scripts/package.sh`: helper packaging script (basic).

## Build Flow (VM)
1. Transfer repo or clone on the VM.
2. Run one of:
   - `./scripts/build.sh -c --pgo`
   - `./scripts/build-optimized.sh --pgo-chromium`
3. Output location: `build/src/out/Default/`

## Incremental Build Tips
- Default builds keep `out/` to maximize reuse; use `--clean` only when necessary.
- `ccache` is enabled automatically when available; ensure it has enough space:
  `ccache -M 20G` (or higher if disk allows).

## Output Packaging (VM)
```
cd ~/plutonium/build/src/out/Default
tar -czvf ~/plutonium-browser.tar.gz \
  chrome chrome_crashpad_handler *.so locales resources.pak \
  icudtl.dat v8_context_snapshot.bin
```

## Build Monitoring
```
# Progress counter
ssh samkl@192.168.0.189 -p 2222 \
  "grep -a -oE '\\[[0-9]+/[0-9]+\\]' ~/plutonium-build.log | tail -1"

# Errors
ssh samkl@192.168.0.189 -p 2222 \
  "grep -iE 'FAILED|error:|fatal' ~/plutonium-build.log | tail -10"

# Is ninja running?
ssh samkl@192.168.0.189 -p 2222 \
  "ps aux | grep ninja | grep -v grep"
```

VM helper (optional):
- `~/plutonium/build-watch.sh` writes status to `~/plutonium-build-status.txt` and
  creates `~/plutonium-browser.tar.gz` when the build finishes.

## Branding and UI
- Global string substitution: `helium-chromium/utils/name_substitution.py` replaces Chrome/Chromium/Helium in `.grd/.xtb`.
- Product branding: `helium-chromium/patches/helium/core/change-chromium-branding.patch` (Plutonium name).
- Onboarding UI branding: `patches/helium/linux/plutonium-onboarding-branding.patch` (strings + logo).
- Neutral gray UI palette: `patches/helium/linux/chrome-default-colors.patch`.
- Resource pipeline: `helium-chromium/utils/generate_resources.py` + `replace_resources.py`.

## Performance Optimizations Enabled
- ThinLTO, -O3, LLVM loop opts (via `patches/helium/linux/compiler-optimizations.patch`).
- AVX/AVX2 SIMD targeting (via `patches/helium/linux/avx2-optimizations.patch` and `flags.linux.gn`).
- PGO (via `--pgo` or `--pgo-*` build modes).
- V8 Sparkplug, Maglev, TurboFan tiers (in `helium-chromium/flags.gn`).
- VA-API, GPU rasterization, zero-copy.
- CFI disabled in `flags.linux.gn` for maximum runtime performance (trade-off: reduced exploit mitigation).

## Incremental Build Tips
- Default builds keep `out/` to maximize reuse; use `--clean` only when necessary.
- `ccache` is enabled automatically; set a larger cache when disk allows:
  `ccache -M 50G`.
- Avoid rerunning name/resource substitution unless branding changes.

## Known Issues and Fixes
- Chromium 143 patch compatibility:
  - `helium/linux/scrolling-performance.patch` and
    `helium/linux/chrome-default-colors.patch` are updated and enabled in
    `patches/series`.
- Invalid GN flag removed:
  - `v8_enable_wasm_code_cache` no longer exists in Chromium 143.
  - `fix_invalid_gn_flags()` in `scripts/shared.sh` removes it before GN gen.
- Node.js ES module issue in webui tools:
  - `fix_nodejs_esm()` writes `{"type": "module"}` to
    `ui/webui/resources/tools/package.json`.
- Onboarding build uses Vite and requires Node 20+:
  - `setup_toolchain()` symlinks `third_party/node/.../bin/node` to `which node`.
  - Ensure `node --version` is >= 20 before build (VM uses NVM v22).
- uBlock file list generator:
  - `third_party/ublock/generate_file_list.py` used `Path.walk()` (py3.12).
  - depot_tools Python is 3.11; patch to `os.walk()` in the VM build tree.

## Current Build Environment (VM)
- Windows host: 8 cores / 16 threads, 32 GB RAM.
- VirtualBox Ubuntu VM:
  - 14 vCPUs, 26 GB RAM.
  - Nested virtualization on, large pages on.
  - SATA host I/O cache enabled.
  - NAT with port forward 2222 -> 22.
- Build dir: `~/plutonium`
- Log: `~/plutonium-build.log`
- Recommended parallelism:
  - `-j14` for compile; drop to `-j12` if ThinLTO link OOMs.

## Local Install Layout (this machine)
- Launcher: `~/.local/bin/plutonium-browser`
- Install dir: `~/.local/share/plutonium-browser/`
- Desktop entry: `~/.local/share/applications/plutonium.desktop`
- Icons: `~/.local/share/icons/hicolor/*/apps/plutonium.png`

To replace the local install, copy new build outputs into
`~/.local/share/plutonium-browser/` and keep the launcher + icons unchanged.

## Handoff Notes
- For fresh builds, start with `./scripts/build.sh -c --pgo` and monitor `~/plutonium-build.log`.
