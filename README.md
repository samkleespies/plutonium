# Plutonium Browser

Plutonium is a high-performance, privacy-focused Chromium-based browser with Thorium-style optimizations.

Based on [Helium](https://github.com/imputnet/helium) and [ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium), with additional performance optimizations inspired by [Thorium](https://github.com/Alex313031/thorium).

## Features

- **Maximum Performance**: -O3 optimization, ThinLTO, PGO support, AVX/AVX2 targeting
- **Privacy First**: Based on ungoogled-chromium with all Google services removed
- **Clean UI**: Chrome's original gray color scheme, no status bubble clutter
- **Smooth Scrolling**: GPU rasterization, zero-copy rendering, optimized compositor

## Building

### Quick Start
```bash
./scripts/build-optimized.sh --pgo-chromium
```

### Build Options
| Mode | Command | Performance |
|------|---------|-------------|
| Standard | `--optimized` | ~90% of Chrome Dev |
| Chromium PGO | `--pgo-chromium` | ~95% of Chrome Dev |
| Custom PGO | `--pgo-custom` | ~98% of Chrome Dev |
| AVX2 + Custom PGO | Enable `use_avx2=true` | ~100% of Chrome Dev |

See [README-OPTIMIZED-BUILD.md](README-OPTIMIZED-BUILD.md) for detailed instructions.

## Credits

- [Helium](https://github.com/imputnet/helium) - Base browser
- [ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium) - Privacy patches
- [Thorium](https://github.com/Alex313031/thorium) - Performance optimization inspiration
- [ungoogled-chromium-portablelinux](https://github.com/ungoogled-software/ungoogled-chromium-portablelinux) - Linux packaging

## License

GPL-3.0 for Plutonium-specific code. See [LICENSE](LICENSE).

Imported code retains original licenses (BSD 3-Clause for ungoogled-chromium code).
