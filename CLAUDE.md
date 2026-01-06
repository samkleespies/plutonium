# Plutonium Browser - AI Agent Context

## Project Overview

Plutonium is a Chromium fork focused on performance and a clean UI for Linux. Key feature: Firefox/Zen-style auto-hiding toolbar (immersive mode).

**Chromium Version**: 143.0.7499.146

## Repository Structure

```
plutonium/
├── helium-chromium/           # Upstream submodule (don't modify directly)
├── patches/
│   ├── plutonium/linux/       # Our patches (main work area)
│   ├── ungoogled-chromium/    # Build fixes
│   └── upstream-fixes/        # Chromium bug fixes
├── scripts/
│   ├── build.sh               # Main build script
│   ├── shared.sh              # Build functions
│   ├── package.sh             # Create AppImage
│   └── setup-build-env.sh     # Install dependencies
├── package/                   # AppImage files
└── flags.linux.gn             # GN build flags
```

## Key Files

| File | Purpose |
|------|---------|
| `patches/plutonium/linux/immersive-mode-linux.patch` | Auto-hiding toolbar implementation |
| `patches/series` | Patch application order |
| `flags.linux.gn` | Build configuration |

## Build Environment

Building happens on a **VirtualBox Ubuntu VM** accessible via:
```bash
ssh samkl@192.168.0.189 -p 2222
```

### VM Paths
- Source: `~/plutonium/build/src/`
- Output: `~/plutonium/build/src/out/Default/`
- Build log: `~/plutonium-build.log`

### Build Commands
```bash
# On VM
export PATH=~/depot_tools:$PATH
cd ~/plutonium/build/src
autoninja -C out/Default chrome -j 12

# Copy binary to local machine
scp -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/chrome ~/.local/share/plutonium-browser/
```

## Immersive Mode Implementation

The auto-hiding toolbar is implemented in:
- `immersive_mode_controller_linux.cc` - Main controller
- `immersive_mode_controller_linux.h` - Header

### How It Works
1. Toolbar slides up/down using layer transforms
2. Mouse position checked via timer (`OnMouseCheckTimer`)
3. Reveals when mouse near top edge, hides when mouse leaves
4. Animation via `gfx::SlideAnimation`

### Known Issues
- Wayland mouse tracking can be unreliable (works in X11/Xephyr)
- Window buttons visibility during hide

## Patches Overview

Applied in order from `patches/series`:

1. **Build fixes** (ungoogled-chromium/)
2. **Performance** - `plutonium-optimizations.patch`, `scrolling-performance.patch`
3. **UI** - `disable-status-bubble.patch`, `chrome-default-colors.patch`, `immersive-mode-linux.patch`
4. **Branding** - `change-chromium-branding.patch`, `plutonium-onboarding-branding.patch`

## Testing

```bash
# Run locally (Wayland)
~/.local/share/plutonium-browser/chrome

# Test in X11 (Xephyr)
Xephyr :2 -screen 1920x1080 &
DISPLAY=:2 ~/.local/share/plutonium-browser/chrome
```

## Common Tasks

### Modify a patch
1. Edit patch file in `patches/plutonium/linux/`
2. Rebuild on VM (patches auto-apply if `.patched.stamp` removed)

### Debug immersive mode
Check browser console or run with logging:
```bash
chrome --enable-logging=stderr --v=1 2>&1 | grep -i immersive
```

### Revert to previous version
```bash
# On VM
cd ~/plutonium
git checkout <commit-hash>
# Remove stamps and rebuild
rm build/src/.patched.stamp build/src/.domsub.stamp
```
