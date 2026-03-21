# Homebrew Tap: Repository Cleanup & README Updates

**Date:** 2026-03-19  
**Task:** Clean up Homebrew files in main repo + add install instructions to README

---

## Part 1: Clean Up Homebrew Tap Files

### Current State

The SoundVibe repository currently contains:
```
SoundVibe/
├── Casks/
│   └── soundvibe.rb          (cask definition, already committed)
├── Formulas/
│   └── .gitkeep              (placeholder, already committed)
└── ...other files...
```

**Git commits:**
- `cbd6493` - chore: update cask to v1.0.1 (latest release)
- `d80896d` - feat: add Homebrew cask definition and release workflow for v1.0.0

---

### The Problem

**These files don't belong in the main SoundVibe repo.**

Why?
- Homebrew taps MUST be in separate repositories named `homebrew-*`
- The cask definition belongs in `bhavpreet/homebrew-soundvibe`, NOT `bhavpreet/SoundVibe`
- Having it in the main repo creates confusion and doesn't actually enable the tap to work
- Users can't `brew tap bhavpreet/soundvibe` and have it work from the main repo

---

### What Should Be Removed

**Remove these from SoundVibe repo:**
- ✅ Delete `Casks/` directory entirely
- ✅ Delete `Formulas/` directory entirely

**Reasoning:**
- The cask definition needs to move to the separate `homebrew-soundvibe` repo
- These directories in the main repo are redundant and confusing
- They don't enable Homebrew functionality
- Clutter the main app repository

---

### What Should Happen Instead

**Step 1: Remove from SoundVibe repo**
```bash
git rm -r Casks/
git rm -r Formulas/
git commit -m "chore: remove Homebrew tap files (moved to separate homebrew-soundvibe repo)"
git push origin main
```

**Step 2: Create separate `homebrew-soundvibe` repo**
- New GitHub repository: `bhavpreet/homebrew-soundvibe`
- Create `Casks/` directory
- Copy `soundvibe.rb` cask definition
- Users: `brew tap bhavpreet/soundvibe && brew install --cask soundvibe`

---

### Clean Up Workflow (For Builder)

1. **Remove from main repo:**
   ```bash
   cd /Users/bhav/dev/SoundVibe
   git rm -r Casks/ Formulas/
   git commit -m "chore: remove Homebrew tap files (belong in separate tap repo)"
   git push origin main
   ```

2. **Create separate tap repo:**
   - GitHub: Create `homebrew-soundvibe` repository
   - Add `Casks/soundvibe.rb` (copy from cask definition)
   - Push to GitHub

3. **Users will then use:**
   ```bash
   brew tap bhavpreet/soundvibe
   brew install --cask soundvibe
   ```

---

## Part 2: Add Homebrew Install Instructions to README

### Where to Add

**Current Installation section structure:**
```markdown
## Installation

### Option 1: Download DMG (Recommended)
### Option 2: Build from Source
```

**Add:** Option 3: Homebrew (as the EASIEST option once tap is set up)

---

### Proposed Addition to README

Insert this **after the System Requirements section** and **within the Installation section**.

**Position:** Between Option 1 and Option 2 (or make it Option 1)

```markdown
### Option 1: Homebrew (Easiest)

Once the Homebrew tap is available:

```bash
brew tap bhavpreet/soundvibe
brew install --cask soundvibe
```

SoundVibe will be installed to `/Applications/SoundVibe.app`.

**To uninstall:**
```bash
brew uninstall --cask soundvibe
```

> **⚠️ macOS Gatekeeper Warning:** See below for workaround.

### Option 2: Download DMG

1. Download **SoundVibe.dmg** from the [latest release](https://github.com/bhavpreet/SoundVibe/releases/latest)
2. Open the DMG and drag **SoundVibe** to **Applications**
3. Launch SoundVibe from Applications

### Option 3: Build from Source

```bash
git clone https://github.com/bhavpreet/SoundVibe.git
cd SoundVibe
swift build -c release
```

To create an installable DMG:
```bash
bash scripts/make-dmg.sh
# Output: dist/SoundVibe.dmg
```
```

---

### Update Gatekeeper Warning Section

The existing Gatekeeper warning section should be updated and moved.

**Current location:** In the "Download DMG" section

**Proposed:** Move to a dedicated section after Installation

```markdown
## macOS Gatekeeper Warning

SoundVibe is not signed with an Apple Developer ID, so macOS will show a security warning the first time you launch it:

> **"Apple could not verify SoundVibe is free of malware."**

This is a standard warning for unsigned applications. **SoundVibe is safe to use** — it's open-source and runs entirely locally on your device.

### How to Bypass the Warning

Choose either method:

#### Method 1: Right-Click (Easiest)

1. Find `SoundVibe.app` in **Finder** (Applications folder)
2. **Right-click** (or Control+click) → Select **"Open"**
3. Click **"Open"** again in the confirmation dialog
4. macOS will remember your choice — no warning on future launches

#### Method 2: Terminal (For Power Users)

```bash
xattr -cr /Applications/SoundVibe.app
open /Applications/SoundVibe.app
```

This removes the quarantine attribute. The app will open normally.

#### Why This Happens

New applications from unknown developers trigger Gatekeeper warnings. Once you've opened SoundVibe once, macOS trusts it and won't show the warning again.

#### Future: Code Signing

Future versions of SoundVibe will be code-signed with an Apple Developer ID, eliminating this warning. For now, either method above works fine.
```

---

## README.md Modification Summary

### Changes Needed

1. **Reorder Installation Options:**
   - Option 1: Homebrew (new, easiest once tap is set up)
   - Option 2: Download DMG (current Option 1)
   - Option 3: Build from Source (current Option 2)

2. **Add Gatekeeper Section:**
   - Move existing Gatekeeper warning to dedicated section
   - Expand with two methods to bypass
   - Add context about why it happens
   - Mention future code signing

3. **Add Link to Tap:**
   - Reference the separate `homebrew-soundvibe` repository
   - Explain that `brew tap bhavpreet/soundvibe` points to that repo

### Files to Edit

**File:** `README.md`

**Sections to update:**
- `## Installation` (reorder options, add Homebrew)
- `## macOS Gatekeeper Warning` (new section or expanded)
- `## Table of Contents` (add new section link if created)

---

## Implementation Checklist (For Builder)

### Part 1: Clean Up Main Repo

- [ ] Verify Casks/ and Formulas/ directories exist in SoundVibe repo
- [ ] Verify they are tracked in git (already committed)
- [ ] Remove: `git rm -r Casks/ Formulas/`
- [ ] Commit: `git commit -m "chore: remove Homebrew tap files (moved to separate tap repo)"`
- [ ] Push: `git push origin main`
- [ ] Verify removal: `git status` shows clean, `ls Casks/` fails

### Part 2: Add README Instructions

- [ ] Open `README.md`
- [ ] Find `## Installation` section
- [ ] Reorder options (Homebrew first, then DMG, then Source)
- [ ] Add Homebrew option with tap instructions
- [ ] Find or create `## macOS Gatekeeper Warning` section
- [ ] Add detailed warning explanation and two bypass methods
- [ ] Add context about code signing
- [ ] Update Table of Contents if adding new section
- [ ] Test that links work (if adding table of contents)
- [ ] Commit: `git commit -m "docs: add Homebrew install instructions and improve Gatekeeper warning"`
- [ ] Push: `git push origin main`

### Part 3: Create Separate Tap Repo

- [ ] Create GitHub repo: `bhavpreet/homebrew-soundvibe`
- [ ] Initialize with README and LICENSE
- [ ] Create `Casks/` directory
- [ ] Create `Casks/soundvibe.rb` (copy from current cask definition)
- [ ] Push to GitHub
- [ ] Test: `brew tap bhavpreet/soundvibe`
- [ ] Test: `brew install --cask soundvibe`

---

## Reference: Current Cask Definition

The cask definition that needs to move to the separate repo:

```ruby
cask "soundvibe" do
  version "1.0.1"
  sha256 "35ccdcea24430fe1292796218e321b1092f4891c5d28e98c3b0f32f4cc396eb3"

  url "https://github.com/bhavpreet/SoundVibe/releases/download/v#{version}/SoundVibe.dmg"
  name "SoundVibe"
  desc "Private, local speech-to-text dictation for macOS"
  homepage "https://github.com/bhavpreet/SoundVibe"

  depends_on macos: ">= :sonoma"

  app "SoundVibe.app"

  zap trash: [
    "~/Library/Application Support/com.soundvibe",
    "~/Library/Preferences/com.soundvibe.plist",
  ]
end
```

This should be copied to:
```
homebrew-soundvibe/
├── Casks/
│   └── soundvibe.rb (this file)
```

---

## Why This Organization Makes Sense

**Main SoundVibe Repo:**
- Contains: Application source code, build scripts, tests, docs
- Purpose: Distribute the application
- Releases: `https://github.com/bhavpreet/SoundVibe/releases/`

**Separate homebrew-soundvibe Tap Repo:**
- Contains: Cask definition(s) for Homebrew distribution
- Purpose: Enable installation via `brew install --cask soundvibe`
- Tap command: `brew tap bhavpreet/soundvibe`
- Points to app releases in main SoundVibe repo

This separation is **standard across Homebrew ecosystem**.

---

## Summary

### What to Remove
- ✅ Delete `Casks/` from SoundVibe repo
- ✅ Delete `Formulas/` from SoundVibe repo
- ✅ Commit removal with message

### What to Add to README
- ✅ Homebrew installation option
- ✅ Detailed Gatekeeper warning section
- ✅ Two bypass methods (right-click and terminal)
- ✅ Context about code signing
- ✅ Reordered installation options

### What to Create Separately
- ✅ New `homebrew-soundvibe` GitHub repository
- ✅ Copy cask definition to new repo
- ✅ Users can then: `brew tap bhavpreet/soundvibe && brew install --cask soundvibe`

