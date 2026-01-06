# Plutonium Browser

A performance-optimized Chromium-based browser for Linux with auto-hiding toolbar and privacy enhancements.

## Features

- **Immersive Mode**: Firefox/Zen-style auto-hiding toolbar that reveals on hover
- **Performance Optimizations**: Compiler and runtime optimizations for speed
- **Privacy Focused**: Based on ungoogled-chromium with additional privacy patches
- **Clean UI**: Minimal interface with status bubble disabled and refined colors

## Building

### Prerequisites

- Ubuntu/Debian-based system (or VM)
- ~50GB disk space
- 16GB+ RAM recommended

### Build Steps

```bash
# Clone the repository
git clone --recurse-submodules https://github.com/user/plutonium.git
cd plutonium

# Set up build environment
./scripts/setup-build-env.sh

# Build (use -j flag to control parallelism)
./scripts/build.sh
```

The built binary will be at `build/src/out/Default/chrome`.

### Packaging

```bash
./scripts/package.sh
```

Creates an AppImage in the `dist/` directory.

## Project Structure

```
plutonium/
├── helium-chromium/     # Upstream Helium submodule (ungoogled-chromium fork)
├── patches/
│   ├── plutonium/linux/ # Plutonium-specific patches
│   ├── ungoogled-chromium/
│   └── upstream-fixes/
├── scripts/             # Build and packaging scripts
├── package/             # AppImage packaging files
└── flags.linux.gn       # Build configuration flags
```

## Patches

| Patch | Description |
|-------|-------------|
| `immersive-mode-linux.patch` | Auto-hiding toolbar with hover reveal |
| `plutonium-optimizations.patch` | Compiler optimizations for performance |
| `scrolling-performance.patch` | Smoother scrolling |
| `chrome-default-colors.patch` | Custom color scheme |
| `disable-status-bubble.patch` | Remove URL preview bubble |
| `change-chromium-branding.patch` | Plutonium branding |

## License

GPL-3.0 - See [LICENSE](LICENSE)

Based on [Chromium](https://www.chromium.org/), [ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium), and [Helium](https://github.com/nicholasmhughes/nicholasmhughes.github.io).
