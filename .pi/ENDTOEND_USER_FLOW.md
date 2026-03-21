# SoundVibe Homebrew Tap: End-to-End User Flow Analysis
**Date:** 2026-03-19  
**Task:** Analyze how the Homebrew tap works for real internet users installing SoundVibe

---

## 1. Prerequisites for Users

### Required
- **Homebrew installed** — Users must have Homebrew package manager
  - Installation: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
  - Takes ~5-10 minutes on first install
  - Requires admin/sudo password

- **macOS 14.0 or later** — As set by `make-dmg.sh` (Info.plist says 13.0, but script overrides)
  - Officially supported: Sonoma (14), Ventura (13), Monterey (12) with caveats
  - Recommended: Sonoma (14) or later for best compatibility

- **2+ GB free disk space** — For app bundle + Whisper models
  - App bundle itself: ~15-20 MB
  - Smallest model (tiny): ~140 MB
  - Base model (default): ~140 MB
  - Larger models: 500 MB to 3+ GB

- **Microphone** — Required functionality (but app will install even without one)

### Optional
- **Apple Developer ID** (optional, only if code-signed) — None needed from user side
- **Admin password** — Homebrew operations typically require sudo for `/usr/local`

---

## 2. User Command Flow

### Step 1: Add the Tap
```bash
brew tap bhavpreet/soundvibe
```
**What happens:**
- Homebrew clones repo: https://github.com/bhavpreet/soundvibe-tap.git
- Stores in: `$(brew --prefix)/Library/Taps/bhavpreet/homebrew-soundvibe/`
- Takes ~5-10 seconds (network dependent)
- No data is downloaded yet

### Step 2: Install the Cask
```bash
brew install --cask soundvibe
```
**What happens:**
- Homebrew reads: `Casks/soundvibe.rb` from tap repo
- Extracts version: `"1.0.0"` (hardcoded in cask)
- Constructs URL: `https://github.com/bhavpreet/SoundVibe/releases/download/v1.0.0/SoundVibe.dmg`
- **Downloads DMG** (2.6 MB) from GitHub releases
- **Verifies SHA256** hash against cask definition
- Mounts DMG automatically
- Copies `SoundVibe.app` to `/Applications/SoundVibe.app`
- Unmounts DMG
- **Cleans up** temporary files
- Takes ~30-60 seconds (network/disk dependent)

### Step 3: First Launch
User opens SoundVibe from Applications (Spotlight, Finder, or `open /Applications/SoundVibe.app`)

**What they see:**
1. **Gatekeeper warning** (PROBLEM):
   - ⚠️ "Apple could not verify SoundVibe is free of malware"
   - Reason: App not signed with Developer ID certificate
   - User must click "Open" to bypass
   - Then click "Open" again in the confirmation dialog
   - OR: `xattr -cr /Applications/SoundVibe.app` in Terminal

2. **Onboarding flow** (first time only):
   - Permission requests: Microphone, Accessibility, Input Monitoring
   - Hotkey configuration
   - Language selection
   - Model download (starts WhisperKit model download)

3. **Minimizes to menu bar** — Normal operation

### Step 4: Update (Later)
```bash
brew upgrade --cask soundvibe
```
**What happens:**
- Homebrew checks if newer version exists in cask
- If version bumped in cask definition (e.g., 1.0.0 → 1.1.0):
  - Downloads new DMG from GitHub release
  - Verifies SHA256
  - Replaces `/Applications/SoundVibe.app`
  - User data preserved (in `~/Library/Application Support/com.soundvibe`)
  - Takes ~30-60 seconds

### Step 5: Uninstall
```bash
brew uninstall --cask soundvibe
```
**What happens:**
- Removes `/Applications/SoundVibe.app`
- With `--zap` flag: removes user data
  ```bash
  brew uninstall --cask --zap soundvibe
  ```
  Removes:
  - `~/Library/Application Support/com.soundvibe/` (Whisper models, cached data)
  - `~/Library/Preferences/com.soundvibe.plist` (Settings)

---

## 3. Where the DMG Comes From: GitHub Releases

### DMG Distribution Source
**Must be hosted on GitHub Releases** for public Homebrew distribution.

**Current situation:**
- ❌ No releases published yet
- DMG exists locally at `/dist/SoundVibe.dmg` but isn't public

**What needs to happen:**

1. **Create GitHub Release** for each version:
   ```
   Tag: v1.0.0 (matches CFBundleShortVersionString)
   Title: SoundVibe 1.0.0
   Description: Release notes
   Artifacts: SoundVibe.dmg (uploaded)
   ```

2. **Generate downloadable URL**:
   ```
   https://github.com/bhavpreet/SoundVibe/releases/download/v1.0.0/SoundVibe.dmg
   ```

3. **Cask references this URL**:
   ```ruby
   url "https://github.com/bhavpreet/SoundVibe/releases/download/v#{version}/SoundVibe.dmg"
   ```

4. **Homebrew downloads from GitHub**:
   - GitHub serves the file (rate-limited but sufficient)
   - ~2.6 MB, takes 5-10 seconds on typical connection
   - SHA256 verified by Homebrew

### Why GitHub Releases?
- ✅ Free hosting
- ✅ Reliable CDN
- ✅ Version-tagged (easy to reference)
- ✅ Release notes per version
- ✅ Integrates with git tags
- ✅ Works well with Homebrew cask workflow

### Alternative (Not Recommended)
- Could host DMG on personal server/S3, but:
  - Additional cost
  - More maintenance
  - Less reliable than GitHub
  - GitHub releases are standard practice

---

## 4. How the Cask Knows Where to Fetch

### Cask Definition Mechanism

**File:** `homebrew-soundvibe/Casks/soundvibe.rb`

```ruby
cask "soundvibe" do
  version "1.0.0"
  sha256 "abc123def456..."
  
  url "https://github.com/bhavpreet/SoundVibe/releases/download/v#{version}/SoundVibe.dmg"
  
  app "SoundVibe.app"
end
```

### How Homebrew Uses This

1. **Version String** is interpolated into URL:
   - `#{version}` → "1.0.0"
   - URL becomes: `https://github.com/bhavpreet/SoundVibe/releases/download/v1.0.0/SoundVibe.dmg`

2. **URL must be publicly accessible**:
   - Homebrew fetches it via curl/wget
   - No authentication required
   - Must be on GitHub Releases (or stable URL)

3. **SHA256 verification**:
   - Homebrew downloads DMG
   - Computes SHA256
   - Compares to `sha256` in cask definition
   - Fails if mismatch (security check)
   - Prevents tampering

### Updating the Cask

When you release v1.1.0:

```ruby
cask "soundvibe" do
  version "1.1.0"                    # ← Update version
  sha256 "new_hash_here_xyz..."      # ← Update SHA256
  
  url "https://github.com/bhavpreet/SoundVibe/releases/download/v#{version}/SoundVibe.dmg"
  
  app "SoundVibe.app"
end
```

Process:
```bash
# 1. Build and create DMG
swift build -c release
bash scripts/make-dmg.sh

# 2. Calculate new SHA256
shasum -a 256 dist/SoundVibe.dmg
# Output: abc123... SoundVibe.dmg

# 3. Create GitHub release with v1.1.0 tag
git tag v1.1.0
git push origin v1.1.0
# Upload dist/SoundVibe.dmg to release

# 4. Update cask definition
# Edit: homebrew-soundvibe/Casks/soundvibe.rb
# - Change version: "1.0.0" → "1.1.0"
# - Change sha256: "old_hash" → "abc123..."
# Commit and push

# 5. Users run:
brew upgrade --cask soundvibe
# Homebrew fetches new cask definition, finds v1.1.0, downloads from GitHub
```

---

## 5. Intel vs Apple Silicon Handling

### Current Situation: ARM64 ONLY
- Binary is arm64 native (Apple Silicon only)
- File: `.build/release/SoundVibe` is "Mach-O 64-bit executable arm64"
- **Intel Macs cannot run this binary**

### What Happens If Intel User Tries to Install?

```bash
# Intel Mac user runs:
brew install --cask soundvibe

# Result:
# 1. DMG downloads successfully (universal problem)
# 2. App copies to /Applications/SoundVibe.app
# 3. User tries to launch
# ❌ "SoundVibe is not compatible with your Mac"
# Error: "binary is an executable for only ARM64"
```

### Why This Is a Problem

| Aspect | Current |
|--------|---------|
| Tap warns Intel users? | ❌ No |
| Installation fails gracefully? | ❌ No |
| Build for both architectures? | ❌ No |
| Documentation warns Intel users? | ⚠️ Only in README |

### Solutions

**Option 1: Document Intel Limitation (Current)**
- Cask metadata: add platform restriction
  ```ruby
  depends_on macos: {
    ">=": "14.0",
    "<": "15.0"
  }
  ```
  But this doesn't restrict architecture (macOS version only)

**Option 2: Build Universal Binary**
- Create arm64 + x86_64 universal binary
  ```bash
  swift build -c release -Xswiftc -target -Xswiftc arm64-apple-macos14
  swift build -c release -Xswiftc -target -Xswiftc x86_64-apple-macos14
  # Combine into universal binary using lipo
  ```
  - Effort: Medium (build system changes)
  - Benefit: One DMG works on both architectures
  - Size increase: ~2x (arm64 ~6.5 MB + x86_64 ~8-10 MB)

**Option 3: Build and Release Separate DMGs**
- Maintain two DMGs:
  - `SoundVibe-arm64.dmg` (Apple Silicon)
  - `SoundVibe-x86_64.dmg` (Intel)
- Cask with architecture detection:
  ```ruby
  if Hardware::CPU.arm?
    url "...SoundVibe-arm64.dmg"
    sha256 "arm64_hash"
  else
    url "...SoundVibe-x86_64.dmg"
    sha256 "intel_hash"
  end
  ```
  - Effort: High (dual build pipelines)
  - Benefit: Both architectures fully supported
  - Complexity: Significant (CI/CD must handle both)

**Option 4: Intel CPU-Only (Lower Performance)**
- Still arm64-only, but document workarounds:
  - Rosetta 2 emulation (slow, ~5-10s transcription)
  - Or: Users build from source on Intel Mac
  - Or: Users use Rosetta terminal to run app
- Effort: Low (just documentation)
- Limitation: Poor performance, requires Rosetta

### Recommended Approach: Document + Build Universal (Later)

**MVP (now):**
- Document: "Apple Silicon only"
- Cask mentions: "arm64" in description
- README has architecture section

**Later (v1.1.0+):**
- Switch to universal binary build
- Single DMG works on both
- No cask complexity

---

## 6. Gatekeeper & Code Signing Warnings

### Current Problem: Ad-Hoc Signing Only

**What users see:**

```
   ⚠️  "Apple could not verify SoundVibe is free of malware."
   
   You will not be able to open the application.
   [Cancel] [Move to Trash]
```

OR (if they right-click):

```
   ⚠️  "SoundVibe" cannot be opened because the developer cannot be verified.
   
   macOS cannot verify that this app is free of malware.
   [Cancel] [Open Anyway]  ← User must click this
```

### Why This Happens

- Current signing: Ad-hoc (`codesign -s -` in make-dmg.sh)
- Ad-hoc signing = no Developer ID certificate
- macOS Gatekeeper sees unsigned app → blocks it

**Current signatures:**
```bash
codesign -d -v /Applications/SoundVibe.app
# Output: ad hoc signature (nosigs)
```

### How Users Bypass (Current)

**Method 1: Right-click (Easy)**
1. Find SoundVibe.app in Finder
2. Right-click (Control+click) → Open
3. Click "Open" in warning dialog
4. App launches
5. macOS remembers choice, won't ask again
6. Takes ~10 seconds extra first run

**Method 2: Terminal (For Developers)**
```bash
xattr -cr /Applications/SoundVibe.app
open /Applications/SoundVibe.app
```
Removes quarantine attribute, app launches normally

**Method 3: System Settings (Not User-Friendly)**
- Settings → Privacy & Security → Security
- Allow SoundVibe to run
- Takes ~30 seconds

### Solution: Apple Developer ID Code Signing

**What's needed:**
1. Apple Developer ID certificate (~$99/year membership)
2. Code signing workflow in build:
   ```bash
   codesign -s "Developer ID Application: Your Name (TEAM_ID)" \
     --deep \
     --force \
     /Applications/SoundVibe.app
   ```
3. App notarization with Apple:
   ```bash
   xcrun notarytool submit dist/SoundVibe.dmg ...
   xcrun stapler staple dist/SoundVibe.dmg
   ```

**Result:**
- ✅ No Gatekeeper warning
- ✅ Users can launch directly
- ✅ Professional appearance
- ✅ Required for App Store distribution

**Cost:**
- Developer ID: $99/year (includes notarization)
- Time to set up: 4-8 hours initial + CI/CD integration

**Effort:** Medium (new CI/CD step)

### Recommendation for Homebrew

**MVP (now):**
- Users must bypass Gatekeeper (right-click or xattr)
- Document process in README
- Acceptable for open-source, grassroots distribution

**Production (v1.1.0+):**
- Get Apple Developer ID
- Integrate code signing + notarization into build
- Users experience no warnings
- Professional distribution

---

## 7. Limitations & Blockers for Public Distribution

### Current Blockers

| Issue | Severity | Impact | Solution |
|-------|----------|--------|----------|
| No GitHub Releases | 🔴 Critical | Users can't install | Create releases with DMG |
| Ad-hoc signing | 🟠 High | Gatekeeper warning | Get Developer ID |
| No version tagging | 🟠 High | Hard to track versions | Add git tags + releases |
| Arm64 only | 🟠 High | Intel users blocked | Build universal or document |
| No CI/CD | 🟡 Medium | Manual builds, error-prone | Add GitHub Actions |
| Hard-coded version | 🟡 Medium | Requires edit for each release | Extract from git tags |

### Non-Blockers (OK as-is)

| Issue | Why It's OK |
|-------|-----------|
| No official Homebrew submission | Tap works fine for distribution |
| Not notarized | Users can bypass with right-click |
| No Sparkle updates | Homebrew handles upgrades |
| No universal binary | Document architecture requirement |

---

## 8. Full End-to-End User Experience Timeline

### New User (First Time)

```
Time    Action                          Duration
────────────────────────────────────────────────
0:00    User: "brew tap bhavpreet/soundvibe"
        Homebrew clones tap repo        ~5s
        
0:05    User: "brew install --cask soundvibe"
        Homebrew reads cask definition  ~1s
        
0:06    Downloads DMG from GitHub       ~20-30s
        (depending on internet speed)   
        
0:36    Verifies SHA256                 ~2s
        
0:38    Mounts DMG                      ~2s
        
0:40    Copies app to /Applications     ~5s
        
0:45    Unmounts, cleans up             ~2s
        
0:47    User: opens SoundVibe from Spotlight
        
0:48    ⚠️  Gatekeeper warning appears
        User clicks "Open" (twice)      ~5s
        
0:53    Onboarding flow starts
        - Microphone permission         ~10s
        - Accessibility permission      ~30s (may require System Settings)
        - Input Monitoring (optional)   ~10s
        - Hotkey configuration          ~15s
        - Model download starts         ~60-120s (depends on model size)
        - Model finishes, app ready     
        
Total first-time setup: ~3-5 minutes (not counting waiting for model download)
```

### Returning User (After Update)

```
Time    Action                          Duration
────────────────────────────────────────────────
0:00    User: "brew upgrade --cask soundvibe"
        Homebrew checks for updates     ~2s
        (if new version available)
        
0:02    Downloads new DMG               ~20-30s
        
0:32    Verifies SHA256                 ~2s
        
0:34    Replaces app in /Applications   ~5s
        
0:39    Done, user relaunches app       ~1s
        
0:40    App starts normally             
        (no Gatekeeper warning again)
        (models preserved from previous install)
        
Total update time: ~40 seconds
User data: Preserved (settings, models, hotkey config)
```

---

## 9. Public Internet User Scenarios

### Scenario 1: Apple Silicon Mac, Decent Internet
- ✅ Everything works
- Gatekeeper warning (minor friction)
- 3-5 minutes to full setup
- **Recommended experience**

### Scenario 2: Intel Mac
- ❌ App won't launch
- Error: "binary is executable for ARM64 only"
- **User must:**
  - Refund/return Homebrew
  - OR: Build from source
  - OR: Use Rosetta + workaround

### Scenario 3: Slow/Restricted Internet
- DMG download takes longer
- GitHub rate limiting (unlikely to hit unless many installs)
- **Still works, just slower**

### Scenario 4: User on older macOS (10.13)
- Installation succeeds (Homebrew allows)
- App fails to launch ("unsupported macOS version")
- **Better: Cask should specify min macOS version**
  ```ruby
  depends_on macos: {
    ">=": "14.0"
  }
  ```

### Scenario 5: No Microphone Attached
- Installation works fine
- App launches
- Onboarding asks for microphone permission
- User skips (no microphone available)
- **Works, but app is not useful**

---

## 10. Checklist for Public Distribution

### Before Going Public

- [ ] **Version tagging** — Add `v1.0.0` git tag
- [ ] **GitHub Release** — Create release with SoundVibe.dmg attached
- [ ] **Calculate SHA256** — Run `shasum -a 256 dist/SoundVibe.dmg`
- [ ] **Create Tap Repo** — `homebrew-soundvibe` on GitHub
- [ ] **Write Cask Definition** — `Casks/soundvibe.rb` with correct URL and SHA256
- [ ] **Test Locally** — `brew tap-new local/test && brew tap local/test`
- [ ] **Test Install** — `brew install --cask soundvibe`
- [ ] **Test Uninstall** — `brew uninstall --cask soundvibe`
- [ ] **Test Zap** — `brew uninstall --cask --zap soundvibe`
- [ ] **Update README** — Include Gatekeeper bypass instructions
- [ ] **Document Architecture** — Note ARM64-only limitation
- [ ] **Test on Clean Mac** — Install from GitHub release, not local file

### For Production-Quality (Later)

- [ ] **Apple Developer ID** — $99/year membership
- [ ] **Code Signing** — Build script integrates codesign
- [ ] **Notarization** — Build script calls xcrun notarytool
- [ ] **CI/CD** — GitHub Actions automates build + sign + notarize + release
- [ ] **Auto SHA256** — Extract hash and auto-update cask
- [ ] **Universal Binary** — Build for both ARM64 + x86_64
- [ ] **Official Homebrew** — Submit to homebrew-casks for inclusion

---

## Summary: What Users Experience

### Command They Type
```bash
brew tap bhavpreet/soundvibe
brew install --cask soundvibe
```

### What Happens Behind the Scenes
1. Homebrew downloads tap repository from GitHub
2. Reads `Casks/soundvibe.rb` cask definition
3. Extracts version and constructs download URL
4. **Downloads DMG from GitHub releases** (2.6 MB, ~20-30 seconds)
5. Verifies SHA256 hash
6. Mounts DMG, copies app to /Applications
7. Homebrew done in ~45 seconds

### First Run
1. User launches app
2. Gatekeeper warning (must click "Open" twice or use xattr)
3. Onboarding flow (~5 minutes including model download)
4. App ready to use

### Update (Later)
```bash
brew upgrade --cask soundvibe
```
- ~40 seconds, preserves user data and models

### Limitations
- **ARM64 only** (Apple Silicon Macs only)
- **No Developer ID signing** (Gatekeeper warning for now)
- **Manual release process** (no CI/CD automation yet)

### To Make It Production-Quality
- Apple Developer ID ($99/year)
- Code signing + notarization
- GitHub Actions CI/CD
- Build universal binary (optional)

