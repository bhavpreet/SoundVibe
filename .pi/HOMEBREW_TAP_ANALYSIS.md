# SoundVibe Homebrew Tap Analysis
**Date:** 2026-03-19  
**Task:** Investigate how to create a Homebrew tap for SoundVibe macOS application

---

## 1. What SoundVibe Is & How It's Built

### Application Overview
- **Name:** SoundVibe
- **Type:** macOS menu bar application (LSUIElement)
- **Language:** Swift 5.12+
- **Platform:** macOS 14.0+ (Sonoma) - minimum macOS 13.0 in code but DMG script sets 14.0
- **Architecture:** ARM64 (Apple Silicon) native binary + intel support (via SwiftUI/AppKit framework)
- **Bundle ID:** `com.soundvibe.app`
- **Version:** 1.0.0 (CFBundleVersion=1)
- **Category:** Productivity (public.app-category.productivity)

### Build Process
```bash
swift build -c release
```

**Build Details:**
- Uses Swift Package Manager (SPM) with `Package.swift` manifest
- Produces executable at: `.build/release/SoundVibe` (arm64 binary, ~6.5 MB)
- Minimum system version: macOS 13.0 (set in Info.plist), but make-dmg.sh updates to 14.0
- Dependencies resolved via SPM (see Package.resolved)

**Key Dependencies:**
- **WhisperKit** (v0.17.0) - CoreML-based Whisper speech-to-text
- swift-transformers, swift-jinja (HuggingFace ecosystem)
- swift-crypto, swift-collections, swift-argument-parser (Apple/utilities)
- yyjson (JSON parsing)

**Linked Frameworks:**
- AppKit, AVFoundation, Carbon, CoreAudio, SwiftUI

---

## 2. Current Distribution Artifacts

### App Bundle Structure
```
dist/SoundVibe.app/
├── Contents/
│   ├── MacOS/
│   │   └── SoundVibe              # arm64 executable (~6.5 MB)
│   ├── Resources/
│   │   ├── AppIcon.icns           # App icon (generated from SF Symbol)
│   │   └── Info.plist             # App metadata
│   ├── Info.plist                 # Main app configuration
│   └── PkgInfo                    # "APPL????" - legacy app type marker
```

### DMG Installer
- **File:** `dist/SoundVibe.dmg` (compressed, ~2.6 MB)
- **Contents:**
  - SoundVibe.app bundle
  - Symlink to /Applications (drag-and-drop target)
  - Hidden .background folder with DMG background image
  - Finder window styling (icon view, 128x128 icons, positioned at {150,190} and {450,190})

**DMG Creation Script:** `scripts/make-dmg.sh` (259 lines)
- Builds release binary
- Creates .app bundle with icon generation via SF Symbols
- Generates DMG background image (separate Swift script)
- Uses AppleScript to style Finder window
- Creates read-write DMG, mounts, styles, converts to compressed UDZO format

### Binary Details
- **Type:** Mach-O 64-bit executable arm64 (Apple Silicon native)
- **Size:** 6.5 MB (uncompressed), ~2.6 MB in DMG (compressed)
- **Code Signing:** Ad-hoc signed by make-dmg.sh (`codesign -s -`)
- **Notarization:** NOT notarized (shows Gatekeeper warning on download)

### Current Installation Methods
1. **DMG Download** (manual) — Users download from GitHub releases
2. **Build from Source** — `git clone` + `swift build -c release` + `scripts/make-dmg.sh`

### Release Process
- **No CI/CD:** No GitHub Actions workflows (`.github/workflows/` doesn't exist)
- **No Git Tags:** No version tags in git history, only commits
- **Manual Process:** User manually runs `make-dmg.sh`, uploads to GitHub Releases
- **Gatekeeper Warning:** App not signed with developer ID, so users must bypass security warning

---

## 3. Homebrew Tap Requirements

### Decision: Cask vs Formula

**SoundVibe should use a Homebrew CASK**, not a formula.

**Why?**
- SoundVibe is a GUI application (.app bundle), not a command-line tool
- Casks are designed for distributing precompiled macOS apps
- Formulas are for building from source or distributing binaries as CLI tools

**Cask vs Formula Comparison:**
| Aspect | Formula | Cask |
|--------|---------|------|
| Use Case | CLI tools, libraries, source builds | GUI apps, precompiled binaries |
| Distribution | Source code (compile locally) | Precompiled .app bundles |
| Installation | `/usr/local/opt/{name}` | `/Applications/{name}.app` |
| SoundVibe Fit | ❌ Not ideal | ✅ Perfect |

### Homebrew Tap Structure

A Homebrew tap is a GitHub repository with a specific structure. For SoundVibe, you'd create:

```
homebrew-soundvibe/  (new GitHub repo)
├── Formula/         (not needed for cask-only)
├── Casks/
│   └── soundvibe.rb (Cask definition)
├── README.md
└── LICENSE
```

**Or embed in existing repo:**
```
SoundVibe/
├── Formula/         (new directory)
├── Casks/           (new directory)
│   └── soundvibe.rb
├── ...existing files...
```

### SoundVibe Cask Definition

Here's what `Casks/soundvibe.rb` would look like:

```ruby
cask "soundvibe" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256_OF_DMG"

  url "https://github.com/bhavpreet/SoundVibe/releases/download/v#{version}/SoundVibe.dmg"
  name "SoundVibe"
  desc "Private, local speech-to-text dictation for macOS"
  homepage "https://github.com/bhavpreet/SoundVibe"

  app "SoundVibe.app"

  zap trash: [
    "~/Library/Application Support/com.soundvibe",
    "~/Library/Preferences/com.soundvibe.plist"
  ]
end
```

**Key Components:**
- `version` — Must match GitHub release tag (e.g., "v1.0.0")
- `sha256` — SHA256 hash of the DMG file (for integrity verification)
- `url` — Must point to a released DMG artifact
- `app` — Specifies what .app bundle to install
- `zap` — Optional cleanup of user data when uninstalling

### Implementation Workflow

**Phase 1: Prepare Release Process**
1. Add version management (currently hardcoded as "1.0.0")
2. Create git tags for releases (e.g., `v1.0.0`, `v1.1.0`)
3. Set up GitHub Releases automation or document manual process
4. Ensure DMG is uploaded to GitHub Releases

**Phase 2: Create Homebrew Tap**
1. Create new GitHub repository: `homebrew-soundvibe` (public)
2. Create `Casks/soundvibe.rb` with above cask definition
3. Document tap installation: `brew tap bhavpreet/soundvibe`
4. Document installation: `brew install --cask soundvibe`

**Phase 3: Submit to Official Homebrew (Optional)**
- Can submit SoundVibe cask to the official Homebrew Casks repo
- Requires: no hardcoded URLs, proper metadata, automated releases
- Users would then simply: `brew install soundvibe` (without tap)

---

## 4. Current Release/Distribution Setup

### Status: MANUAL, NO CI/CD

**Current Process:**
1. Developer locally builds: `swift build -c release`
2. Developer creates DMG: `bash scripts/make-dmg.sh`
3. Developer manually uploads DMG to GitHub Releases
4. Users download manually or build from source

**Problems:**
- ❌ No automation (error-prone, inconsistent builds)
- ❌ No CI verification (untested builds might be released)
- ❌ No version tagging
- ❌ No checksum verification (SHA256)
- ❌ Ad-hoc code signing only (not production-quality)

### GitHub Repository
- **Owner:** bhavpreet
- **Repo:** SoundVibe
- **URL:** https://github.com/bhavpreet/SoundVibe
- **Status:** No releases published yet (git history only)

### Code Signing Status
- **Current:** Ad-hoc signed by `codesign -s -`
- **Issue:** Users get "Apple could not verify..." warning
- **Workaround:** Users must right-click → Open, or `xattr -cr /Applications/SoundVibe.app`
- **For Production:** Should obtain Apple Developer ID (requires Apple Developer membership, ~$99/year)

### Notarization Status
- **Current:** NOT notarized
- **Impact:** Gatekeeper warning on download/first run
- **For Production:** Should notarize with Apple (requires Developer ID, done via `xcrun notarytool`)

---

## 5. Homebrew Tap Implementation Strategy

### Recommended Approach: Tap + Signed Releases

**Short Term (MVP for Homebrew):**
1. ✅ Keep existing DMG build process in `scripts/make-dmg.sh`
2. ✅ Create `homebrew-soundvibe` tap with cask definition
3. ✅ Set up GitHub Releases with version tags
4. ✅ Calculate and document SHA256 hashes
5. Users: `brew tap bhavpreet/soundvibe && brew install --cask soundvibe`

**Medium Term (Production Quality):**
1. Add CI/CD (GitHub Actions) to auto-build, sign, notarize, and release
2. Obtain Apple Developer ID and sign app properly
3. Notarize DMG
4. Auto-calculate SHA256 and update cask definition
5. Auto-tag releases in git

**Long Term (Official Homebrew):**
1. Submit to official homebrew-casks
2. No tap needed: `brew install soundvibe`

### SHA256 Calculation
```bash
shasum -a 256 dist/SoundVibe.dmg
# Output: 1a2b3c4d5e6f... SoundVibe.dmg
# Use the hash in the cask definition
```

### Current SHA256 (for existing DMG)
```bash
cd /Users/bhav/dev/SoundVibe
shasum -a 256 dist/SoundVibe.dmg
```

---

## 6. Checklist for Homebrew Tap Creation

### Prerequisites
- [ ] Apple Developer ID (optional but recommended) — $99/year
- [ ] Notarization setup (optional but recommended)
- [ ] GitHub Releases workflow (publish DMG with version tags)
- [ ] SHA256 hashing process (automated or documented)

### Cask Development
- [ ] Create `homebrew-soundvibe` repo on GitHub
- [ ] Create `Casks/soundvibe.rb` with proper metadata
- [ ] Test cask locally: `brew tap-new local/test && brew tap local/test`
- [ ] Verify install/uninstall: `brew install --cask soundvibe`
- [ ] Document tap usage in README

### Release Process
- [ ] Establish version numbering (semantic versioning)
- [ ] Create git tag for each release (e.g., `v1.0.0`)
- [ ] Build DMG with version in script (currently hardcoded)
- [ ] Calculate SHA256 of DMG
- [ ] Create GitHub Release with DMG artifact
- [ ] Update cask definition SHA256 and version
- [ ] Tag tap repo with corresponding version

### Quality Assurance
- [ ] Test install on clean Mac
- [ ] Test uninstall with zap
- [ ] Test update to newer version
- [ ] Verify no Gatekeeper warnings (if signed properly)
- [ ] Verify app launches and works

---

## 7. Sample Implementation Timeline

### Week 1: MVP Homebrew Tap
- Create `homebrew-soundvibe` repo
- Write `Casks/soundvibe.rb`
- Calculate SHA256 for current DMG
- Test locally
- Document in README

### Week 2: Automated Releases
- Set up GitHub Actions for building DMG
- Auto-calculate SHA256
- Auto-create releases
- Auto-update cask definition

### Week 3: Code Signing (if pursuing)
- Obtain Apple Developer ID
- Integrate signing into build
- Set up notarization
- Test on clean Mac

### Week 4: Official Homebrew (Optional)
- Submit to official homebrew-casks
- Integrate feedback from reviewers
- Finalize for inclusion

---

## 8. Open Questions & Considerations

1. **Apple Developer ID Signing**
   - Will you invest in code signing and notarization?
   - Current ad-hoc signing is fine for open-source, but production apps should be signed

2. **Release Frequency**
   - How often will SoundVibe release new versions?
   - This affects automation complexity

3. **CI/CD Investment**
   - Should releases be automated or manual?
   - Automated is better but requires GitHub Actions setup

4. **Tap Name**
   - `homebrew-soundvibe` (public tap) vs. submit to official Homebrew?
   - Official Homebrew is more convenient for users

5. **Version Management**
   - Currently hardcoded as "1.0.0"
   - Should be automated from git tags or explicitly managed

6. **Sparkle Updates (Optional)**
   - Consider integrating Sparkle framework for in-app updates
   - Users wouldn't need `brew upgrade soundvibe`
   - More seamless UX, but additional complexity

7. **Intel Mac Support**
   - Current DMG is Apple Silicon only (arm64)
   - Should we build universal binary (arm64 + x86_64)?
   - Would require broader testing and build matrix

---

## Summary

### What's Needed for Homebrew

| Component | Status | Effort |
|-----------|--------|--------|
| DMG Distribution | ✅ Exists | Low |
| GitHub Releases | ❌ Not set up | Low |
| Version Tagging | ❌ Not set up | Low |
| Cask Definition | ❌ Needs creation | Low |
| Homebrew Tap | ❌ Needs creation | Low |
| CI/CD (optional) | ❌ Not set up | Medium |
| Code Signing (optional) | ❌ Not set up | Medium |
| Notarization (optional) | ❌ Not set up | Medium |

### Recommended MVP (1-2 weeks)
1. Create `homebrew-soundvibe` tap repo
2. Write cask definition for v1.0.0
3. Set up GitHub Releases with DMG
4. Document installation: `brew tap bhavpreet/soundvibe && brew install --cask soundvibe`
5. Test on clean Mac

### Production Quality (4-8 weeks)
1. Implement CI/CD with GitHub Actions
2. Obtain Apple Developer ID
3. Set up code signing and notarization in CI
4. Automate SHA256 calculation and cask updates
5. Document update process

---

## Files & Artifacts Summary

**Current Build Artifacts:**
- Binary: `.build/release/SoundVibe` (6.5 MB, arm64)
- App Bundle: `dist/SoundVibe.app/`
- DMG Installer: `dist/SoundVibe.dmg` (2.6 MB)

**Scripts:**
- Build: `scripts/make-dmg.sh`
- Icon generation: `scripts/generate-dmg-background.swift`

**Metadata:**
- Bundle ID: `com.soundvibe.app`
- Version: `1.0.0` (in Info.plist)
- Min macOS: 13.0 (Info.plist) → 14.0 (DMG script)
- Dependencies: WhisperKit, swift-transformers, swift-crypto, etc.

**GitHub:**
- Repository: https://github.com/bhavpreet/SoundVibe
- No current releases or tags
