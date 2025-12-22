# CLAUDE.md - Technical Documentation for AI Agents

This document contains all technical details needed for an AI agent to continue development on Plutonium Browser.

## Project Overview

Plutonium is a Chromium fork focused on performance and privacy, with a custom auto-hiding toolbar feature in development.

**Chromium Version:** 143.0.7499.146
**Base:** ungoogled-chromium → Helium → Plutonium

---

## SSH Access & Build Environment

### VM Connection (Primary Build Environment)

```bash
# Ubuntu VM running on VirtualBox (Windows host)
ssh samkl@192.168.0.189 -p 2222

# Username: samkl
# Build directory: ~/plutonium/build/src
# Depot tools: ~/depot_tools
```

### Windows Host PC

```bash
ssh samkl@192.168.0.189
# Used to manage VirtualBox VMs if needed
```

### VM Management (from host)

```bash
# Check VM status
VBoxManage list runningvms

# Start VM
VBoxManage startvm "Ubuntu" --type headless
```

---

## Build Commands

### Full Build (from scratch)

```bash
# On VM
cd ~/plutonium
./scripts/build.sh -c --pgo
```

### Incremental Build (after source changes)

```bash
# On VM - MOST COMMON COMMAND
ssh samkl@192.168.0.189 -p 2222 "export PATH=~/depot_tools:\$PATH && cd ~/plutonium/build/src && autoninja -C out/Default chrome"
```

### Check Build Status

```bash
# Is build running?
ssh samkl@192.168.0.189 -p 2222 "ps aux | grep -E '(autoninja|ninja)' | grep -v grep"

# View recent build output
ssh samkl@192.168.0.189 -p 2222 "tail -50 ~/plutonium-build.log"
```

---

## Local Installation (User's Machine)

### Paths

```
~/.local/share/plutonium-browser/     # Install directory
~/.local/share/plutonium-browser.backup-*  # Backups (timestamped)
```

### Required Files for Installation

| File | Size | Purpose |
|------|------|---------|
| chrome | ~425MB | Main browser binary |
| chrome_crashpad_handler | ~2MB | Crash reporting |
| chrome_100_percent.pak | ~720KB | UI resources (icons!) |
| chrome_200_percent.pak | ~1.2MB | HiDPI resources |
| resources.pak | ~21MB | General resources |
| icudtl.dat | ~11MB | ICU internationalization |
| v8_context_snapshot.bin | ~711KB | V8 startup snapshot |
| libEGL.so, libGLESv2.so | ~9MB | Graphics libraries |
| libqt5_shim.so, libqt6_shim.so | ~75KB | Qt integration |
| libvk_swiftshader.so | ~6MB | Vulkan software renderer |
| locales/ | ~20MB | Language files |

### Copy Commands

```bash
# Backup existing installation
mv ~/.local/share/plutonium-browser ~/.local/share/plutonium-browser.backup-$(date +%Y%m%d-%H%M%S)

# Create new directory
mkdir -p ~/.local/share/plutonium-browser

# Copy all required files
scp -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/chrome ~/.local/share/plutonium-browser/
scp -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/chrome_crashpad_handler ~/.local/share/plutonium-browser/
scp -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/chrome_*.pak ~/.local/share/plutonium-browser/
scp -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/{icudtl.dat,resources.pak,v8_context_snapshot.bin} ~/.local/share/plutonium-browser/
scp -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/lib*.so ~/.local/share/plutonium-browser/
scp -r -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/locales ~/.local/share/plutonium-browser/
```

### Launch Browser

```bash
~/.local/share/plutonium-browser/chrome
```

---

## Current Feature: Auto-Hiding Toolbar (Immersive Mode)

### Goal

Create a Firefox/Zen-browser-style auto-hiding toolbar that:
1. Hides automatically when not in use
2. Reveals when mouse hovers at top edge of window
3. Works in normal maximized mode (not just fullscreen)
4. Animates smoothly in and out

### Implementation Status: BROKEN - CRASHES ON STARTUP

The current implementation causes the browser to crash on launch.

### Files Modified on VM

All modifications are in: `~/plutonium/build/src/chrome/browser/ui/views/frame/`

#### 1. New Files Created

**immersive_mode_controller_linux.h** (~135 lines)
```
Location: chrome/browser/ui/views/frame/immersive_mode_controller_linux.h
```
- Defines `ImmersiveModeControllerLinux` class
- Inherits from: `ImmersiveModeController`, `gfx::AnimationDelegate`, `ui::EventObserver`, `views::FocusChangeListener`, `views::WidgetObserver`
- Key constants: `kTopEdgeThresholdDip = 3`, `kRevealDelay = 200ms`, `kAnimationDuration = 200ms`

**immersive_mode_controller_linux.cc** (~329 lines)
```
Location: chrome/browser/ui/views/frame/immersive_mode_controller_linux.cc
```
- Full implementation of auto-hiding toolbar
- Uses `gfx::SlideAnimation` for animations
- Tracks mouse via `aura::Env::AddEventObserver`
- Updates layout via `UpdateTopContainerOffset()`

#### 2. Modified Chromium Files

**chrome/common/chrome_features.cc**
```cpp
// Added Linux to the feature guard
#if BUILDFLAG(IS_MAC) || BUILDFLAG(IS_LINUX)
BASE_FEATURE(kImmersiveFullscreen, base::FEATURE_ENABLED_BY_DEFAULT);
#endif
```

**chrome/common/chrome_features.h**
```cpp
// Added Linux to declaration
#if BUILDFLAG(IS_MAC) || BUILDFLAG(IS_LINUX)
COMPONENT_EXPORT(CHROME_FEATURES) BASE_DECLARE_FEATURE(kImmersiveFullscreen);
#endif
```

**chrome/browser/ui/views/frame/immersive_mode_controller_factory_views.cc**
```cpp
// Added Linux case in factory function
#if BUILDFLAG(IS_LINUX)
#include "chrome/browser/ui/views/frame/immersive_mode_controller_linux.h"
...
#elif BUILDFLAG(IS_LINUX)
  if (base::FeatureList::IsEnabled(features::kImmersiveFullscreen)) {
    return std::make_unique<ImmersiveModeControllerLinux>(browser_view->browser());
  }
  return std::make_unique<ImmersiveModeControllerStub>(browser_view->browser());
#endif
```

**chrome/browser/ui/views/frame/browser_view.cc**

Two modifications:

1. Around line 2189 - Enable immersive in `FullscreenStateChanged()`:
```cpp
#if BUILDFLAG(IS_LINUX)
  // Enable immersive mode on Linux when entering fullscreen
  if (UsesImmersiveFullscreenMode()) {
    ImmersiveModeController::From(browser())->SetEnabled(IsFullscreen());
  }
#endif
```

2. Around line 5258 - Enable immersive on window init:
```cpp
immersive_mode_controller->Init(this);
immersive_mode_controller->AddObserver(this);
#if BUILDFLAG(IS_LINUX)
  // Enable immersive mode on Linux for normal window mode
  if (UsesImmersiveFullscreenMode()) {
    immersive_mode_controller->SetEnabled(true);
  }
#endif
```

**chrome/browser/ui/views/frame/browser_view.h**
```cpp
// Modified to include Linux
#if BUILDFLAG(IS_MAC) || BUILDFLAG(IS_LINUX)
bool UsesImmersiveFullscreenMode() const;
#endif
```

**chrome/browser/ui/BUILD.gn**
```gn
# Added to Linux sources section (around line 3366)
if (is_linux) {
  sources += [
    "views/frame/immersive_mode_controller_linux.cc",
    "views/frame/immersive_mode_controller_linux.h",
  ]
}
```

**chrome/browser/about_flags.cc**
```cpp
// Added Linux flag entry after Mac entry
#if BUILDFLAG(IS_LINUX)
    {"enable-immersive-fullscreen-toolbar",
     flag_descriptions::kImmersiveFullscreenName,
     flag_descriptions::kImmersiveFullscreenDescription, kOsLinux,
     FEATURE_VALUE_TYPE(features::kImmersiveFullscreen)},
#endif
```

### Known Issues with Current Implementation

1. **CRASH ON STARTUP** - Browser crashes immediately when launched
   - Likely cause: `SetEnabled(true)` called too early during init
   - `browser_view_` or other pointers may not be fully initialized

2. **Previous issues (before crash):**
   - Layout was broken/messed up when toolbar revealed
   - Couldn't interact with toolbar elements (click, type URL)
   - Hide animation was instant instead of smooth

### Debugging the Crash

To debug:
```bash
# Run with debugging output
~/.local/share/plutonium-browser/chrome --enable-logging=stderr --v=1 2>&1 | head -100

# Or check crash dumps
ls ~/.config/chromium/Crash\ Reports/
```

### Potential Fix Strategies

1. **Delay SetEnabled call** - Don't enable immersive mode during Init, wait for first layout
2. **Check null pointers** - `browser_view_`, `GetWidget()`, `top_container()` may be null
3. **Disable the feature temporarily** - Comment out `SetEnabled(true)` in browser_view.cc line ~5263
4. **Revert to fullscreen-only** - Keep `SetEnabled(IsFullscreen())` only

### To Disable Feature Temporarily

On VM:
```bash
# Comment out the problematic SetEnabled call
ssh samkl@192.168.0.189 -p 2222 "sed -i 's/immersive_mode_controller->SetEnabled(true);/\/\/ immersive_mode_controller->SetEnabled(true);/' ~/plutonium/build/src/chrome/browser/ui/views/frame/browser_view.cc"

# Rebuild
ssh samkl@192.168.0.189 -p 2222 "export PATH=~/depot_tools:\$PATH && cd ~/plutonium/build/src && autoninja -C out/Default chrome"

# Copy to local
scp -P 2222 samkl@192.168.0.189:~/plutonium/build/src/out/Default/chrome ~/.local/share/plutonium-browser/
```

---

## Chromium Architecture Notes

### ImmersiveModeController Interface

The base interface (`ImmersiveModeController`) defines:
- `Init(BrowserView*)` - Initialize with browser view
- `SetEnabled(bool)` - Enable/disable immersive mode
- `IsEnabled()` / `IsRevealed()` - State queries
- `GetTopContainerVerticalOffset()` - Returns negative offset to slide toolbar up
- `GetRevealedLock()` - Lock mechanism to keep toolbar visible

### Layout System

- `BrowserViewLayoutImpl` uses `GetTopContainerVerticalOffset()` to position toolbar
- `TopContainerView::OnImmersiveRevealUpdated()` must be called when animation updates
- `DeprecatedLayoutImmediately()` forces synchronous layout recalculation
- `contents_container()->InvalidateLayout()` updates content area

### How ChromeOS Does It

ChromeOS has a working implementation in:
- `immersive_mode_controller_chromeos.cc`
- Uses `chromeos::ImmersiveFullscreenController` (sophisticated system)
- Calls proper layout methods when updating

---

## Patch System

### Patch Application Order

Defined in `patches/series`:
```
ungoogled-chromium/portablelinux/...
upstream-fixes/...
helium/linux/plutonium-optimizations.patch
helium/linux/scrolling-performance.patch
helium/linux/disable-status-bubble.patch
helium/linux/chrome-default-colors.patch
helium/linux/plutonium-onboarding-branding.patch
helium/linux/immersive-mode-linux.patch
helium/linux/change-chromium-branding.patch
...
```

### The immersive-mode-linux.patch

Currently only contains flag entry in about_flags.cc. The actual implementation files were created directly on the VM (not in patch form yet).

---

## Common Operations

### View/Edit File on VM

```bash
# View file
ssh samkl@192.168.0.189 -p 2222 "cat ~/plutonium/build/src/chrome/browser/ui/views/frame/immersive_mode_controller_linux.cc"

# Edit with sed
ssh samkl@192.168.0.189 -p 2222 "sed -i 's/old/new/' ~/plutonium/build/src/path/to/file.cc"

# Check line count
ssh samkl@192.168.0.189 -p 2222 "wc -l ~/plutonium/build/src/path/to/file.cc"
```

### Search Codebase

```bash
# Find files
ssh samkl@192.168.0.189 -p 2222 "find ~/plutonium/build/src/chrome -name '*immersive*'"

# Search content
ssh samkl@192.168.0.189 -p 2222 "grep -rn 'ImmersiveMode' ~/plutonium/build/src/chrome/browser/ui/views/frame/ --include='*.cc' | head -20"
```

### Create File with Content

```bash
# Using heredoc (watch for special characters)
ssh samkl@192.168.0.189 -p 2222 "cat > /path/file.cc << 'EOF'
content here
EOF"

# Or use Python for complex content
ssh samkl@192.168.0.189 -p 2222 "python3 -c \"
content = '''your code here'''
with open('/path/file.cc', 'w') as f:
    f.write(content)
\""
```

---

## Troubleshooting

### VM Not Responding

```bash
# Check if VM is running (from Windows host)
ssh samkl@192.168.0.189 "VBoxManage list runningvms"

# Ping test
ping -c 2 192.168.0.189
```

### Build Errors

```bash
# Check for errors
ssh samkl@192.168.0.189 -p 2222 "grep -i 'error:' ~/plutonium-build.log | tail -20"

# Full error context
ssh samkl@192.168.0.189 -p 2222 "grep -B 5 -A 10 'error:' ~/plutonium-build.log | tail -50"
```

### Missing Icons (Yellow Square)

Ensure `chrome_100_percent.pak` and `chrome_200_percent.pak` are copied to install directory.

### Browser Crashes

1. Check stderr output: `./chrome 2>&1 | head -100`
2. Check for missing .pak files
3. Disable problematic features via command line flags

---

## Reference: ChromeOS Immersive Mode

For reference, ChromeOS's working implementation:

**File:** `chrome/browser/ui/views/frame/immersive_mode_controller_chromeos.cc`

Key method that updates layout properly:
```cpp
void ImmersiveModeControllerChromeos::LayoutBrowserRootView() {
  browser_view_->top_container()->OnImmersiveRevealUpdated();
  browser_view_->DeprecatedLayoutImmediately();
  browser_view_->contents_container()->InvalidateLayout();
}
```

---

## Version History

| Date | Change |
|------|--------|
| 2025-12-22 | Created immersive mode implementation (crashes on start) |
| 2025-12-20 | Initial Plutonium build working |
| 2025-12-18 | Project setup |

---

## Contact / Resources

- Local repo: `/home/samk/projects/plutonium`
- VM build: `samkl@192.168.0.189:~/plutonium/build/src`
- Chromium source: https://source.chromium.org/chromium
- Helium upstream: `helium-chromium/` submodule
