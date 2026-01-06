# Plutonium Browser

A personal browser project born out of wanting the best of both worlds: the privacy and clean aesthetics of [Helium](https://github.com/nicholasmhughes/nicholasmhughes.github.io) (an ungoogled-chromium fork I really liked), combined with the raw speed and smoothness you get from Chrome Dev.

I also wanted that immersive, distraction-free browsing experience - think Firefox/Zen-style auto-hiding toolbar that gets out of your way until you need it.

## What This Is

- **Based on Helium** - All the privacy features and nice UI I liked from Helium
- **Performance tuned** - Compiler optimizations and tweaks to match Chrome Dev's snappiness
- **Immersive mode** - Auto-hiding toolbar that reveals on hover (work in progress on Wayland)
- **Linux focused** - Built and tested on Linux

## Building

Building requires a beefy machine (or VM). I use an Ubuntu VM with 15 cores and 28GB RAM.

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/samkleespies/plutonium.git
cd plutonium

# Set up dependencies
./scripts/setup-build-env.sh

# Build
./scripts/build.sh
```

Binary ends up at `build/src/out/Default/chrome`.

## Project Structure

```
plutonium/
├── helium-chromium/           # Upstream Helium submodule
├── patches/plutonium/linux/   # My patches
├── scripts/                   # Build scripts
├── package/                   # AppImage stuff
└── flags.linux.gn             # Build flags
```

## License

GPL-3.0
