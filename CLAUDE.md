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

### Incremental Rebuild (after patch changes)
```bash
# Copy updated patch to VM
scp -P 2222 patches/plutonium/linux/immersive-mode-linux.patch samkl@192.168.0.189:~/plutonium/patches/plutonium/linux/

# On VM: regenerate build files and rebuild
cd ~/plutonium/build/src
./out/Default/gn gen out/Default
autoninja -C out/Default chrome -j 12
```

## Immersive Mode Implementation

The auto-hiding toolbar is implemented in:
- `immersive_mode_controller_linux.cc` - Main controller
- `immersive_mode_controller_linux.h` - Header

### How It Works
1. On enable, tab strip is reparented into `top_container` so everything moves together
2. `top_container` gets a compositor layer for GPU-accelerated transforms
3. Mouse position checked via `display::Screen::GetCursorScreenPoint()`
4. When mouse near top edge, `StartReveal()` animates `visible_fraction_` from 0 to 1
5. Transform applied: `transform.Translate(0, height * (visible_fraction_ - 1.0))`
6. When mouse leaves top area, `StartClose()` animates back to hidden

### Key Functions
- `SetEnabled()` - Enables/disables immersive mode, sets up event observers
- `ApplyTransform()` - Applies Y translation to slide toolbar
- `EnsureSlideLayers()` - Creates compositor layer on top_container
- `IsMouseOverTopControls()` - Checks if mouse is in reveal zone

### Known Issues
- Wayland mouse tracking can be unreliable (`display::Screen::GetCursorScreenPoint()` may return stale values)
- Works reliably in X11/Xephyr

## Testing Workflow

**IMPORTANT**: Always test in Xephyr (X11) before having user test on native Wayland.

### 1. Test in Xephyr (X11 mode)
```bash
# Start Xephyr
Xephyr :2 -screen 1920x1080 &

# Run browser in X11 mode
DISPLAY=:2 ~/.local/share/plutonium-browser/chrome --ozone-platform=x11

# Test: move mouse to top edge - toolbar should reveal
# Test: move mouse away - toolbar should hide
```

### 2. Test on native Wayland
```bash
~/.local/share/plutonium-browser/chrome
```

### 3. Debug with logging
```bash
chrome --enable-logging=stderr --v=1 2>&1 | grep -i immersive
```

## Patches Overview

Applied in order from `patches/series`:

1. **Build fixes** (ungoogled-chromium/)
2. **Performance** - `plutonium-optimizations.patch`, `scrolling-performance.patch`
3. **UI** - `disable-status-bubble.patch`, `chrome-default-colors.patch`, `immersive-mode-linux.patch`
4. **Branding** - `change-chromium-branding.patch`, `plutonium-onboarding-branding.patch`

## Common Tasks

### Modify immersive mode patch
1. Edit `patches/plutonium/linux/immersive-mode-linux.patch`
2. Copy to VM: `scp -P 2222 patches/plutonium/linux/immersive-mode-linux.patch samkl@192.168.0.189:~/plutonium/patches/plutonium/linux/`
3. On VM: `cd ~/plutonium/build/src && ./out/Default/gn gen out/Default && autoninja -C out/Default chrome -j 12`
4. Copy binary: `scp -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/chrome ~/.local/share/plutonium-browser/`
5. Test in Xephyr first, then native

### Revert to previous version
```bash
# On VM
cd ~/plutonium
git checkout <commit-hash>
# Remove stamps and rebuild
rm build/src/.patched.stamp build/src/.domsub.stamp
```

### Check VM status
```bash
# Check if VM is running
ssh -o ConnectTimeout=10 samkl@192.168.0.189 -p 2222 "uptime"

# Start VM if needed (from Windows host)
ssh samkl@192.168.0.189 "VBoxManage startvm Ubuntu --type headless"

# Check build progress
ssh samkl@192.168.0.189 -p 2222 "tail -5 ~/plutonium-build.log"
```
