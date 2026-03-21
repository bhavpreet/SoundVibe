# CORRECTION: Homebrew Tap Setup - Separate Repository Required

**Date:** 2026-03-19 (Updated)  
**Status:** Previous recommendation was INCORRECT

---

## What Went Wrong

### Initial Recommendation (WRONG)
- **Proposed:** Embed tap in existing `bhavpreet/SoundVibe` repository
- **Reasoning:** Single repo, simpler maintenance
- **Reality:** Doesn't work with Homebrew's name resolution

### Error Encountered
```
Error: Failure while executing; `git clone https://github.com/bhavpreet/homebrew-soundvibe 
/opt/homebrew/Library/Taps/bhavpreet/homebrew-soundvibe --origin=origin` exited with 128
```

**Root Cause:** Homebrew looks for repository named `homebrew-soundvibe`, not `SoundVibe`

---

## Homebrew Tap Name Resolution (The Truth)

When user runs:
```bash
brew tap bhavpreet/soundvibe
```

Homebrew attempts to clone FROM (in order):
1. `https://github.com/bhavpreet/homebrew-soundvibe` ← Primary pattern
2. `https://github.com/bhavpreet/soundvibe` ← Fallback

**The `homebrew-` prefix is required.** This is non-negotiable Homebrew behavior.

---

## Correct Solution: Separate Repository

### Create `homebrew-soundvibe` Repository

**Repository name:** `homebrew-soundvibe`  
**Full URL:** `https://github.com/bhavpreet/homebrew-soundvibe`  
**GitHub path:** `bhavpreet/homebrew-soundvibe`

**Directory structure:**
```
homebrew-soundvibe/
├── Casks/
│   └── soundvibe.rb
├── Formulas/           (optional, can be empty)
├── README.md
└── LICENSE
```

### Cask Definition

**File:** `Casks/soundvibe.rb`

```ruby
cask "soundvibe" do
  version "1.0.0"
  sha256 "abc123def456..."

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

### User Installation

```bash
brew tap bhavpreet/soundvibe
brew install --cask soundvibe
```

**How it works:**
1. Homebrew clones: `https://github.com/bhavpreet/homebrew-soundvibe`
2. Finds: `Casks/soundvibe.rb`
3. Downloads DMG from: URL in cask (references `bhavpreet/SoundVibe`)
4. Installs app to: `/Applications/SoundVibe.app`

---

## Why Embedding in Existing Repo Doesn't Work

### The Mismatch

| Aspect | Value |
|--------|-------|
| Current repo name | `SoundVibe` |
| Current repo URL | `https://github.com/bhavpreet/SoundVibe` |
| Homebrew looks for | `https://github.com/bhavpreet/homebrew-soundvibe` |
| URLs match? | ❌ NO |

### Why You Can't Just Add Casks/

Adding `Casks/` directory to `bhavpreet/SoundVibe` repo doesn't change:
- The repository name
- The URL that Homebrew tries to clone
- The naming mismatch

Homebrew will still try to clone `homebrew-soundvibe` and fail.

### Why You Can't Rename the Main Repo

Renaming `SoundVibe` repo to `homebrew-soundvibe`:
- ❌ Breaks all existing links, forks, issues
- ❌ Changes the main project URL
- ❌ Too disruptive for existing users
- ❌ Not practical

---

## Comparison: Wrong vs Right

### ❌ WRONG APPROACH
```
bhavpreet/SoundVibe/
├── SoundVibe/
├── Casks/
├── Package.swift
└── ...

brew tap bhavpreet/soundvibe
→ Homebrew looks for: bhavpreet/homebrew-soundvibe
→ Doesn't find it: ❌ ERROR
```

### ✅ RIGHT APPROACH
```
bhavpreet/SoundVibe/              (existing app repo)
└── (no changes needed)

bhavpreet/homebrew-soundvibe/     (new tap repo)
├── Casks/soundvibe.rb
└── (cask definition only)

brew tap bhavpreet/soundvibe
→ Homebrew clones: bhavpreet/homebrew-soundvibe
→ Finds Casks/soundvibe.rb: ✅ SUCCESS
```

---

## Release Workflow (With Separate Tap)

### When you release SoundVibe v1.1.0:

1. **In SoundVibe repo:**
   ```bash
   swift build -c release
   bash scripts/make-dmg.sh
   git tag v1.1.0
   git push origin v1.1.0
   # Upload dist/SoundVibe.dmg to GitHub release
   ```

2. **Calculate SHA256:**
   ```bash
   shasum -a 256 dist/SoundVibe.dmg
   # Output: abc123... SoundVibe.dmg
   ```

3. **In homebrew-soundvibe repo:**
   ```bash
   # Edit Casks/soundvibe.rb:
   # - version "1.0.0" → "1.1.0"
   # - sha256 "old_hash" → "abc123..."
   
   git add Casks/soundvibe.rb
   git commit -m "Update cask for SoundVibe v1.1.0"
   git push origin main
   ```

4. **Users upgrade:**
   ```bash
   brew upgrade --cask soundvibe
   ```

---

## Why This Is Actually Standard

**Most Homebrew taps follow this pattern:**
- `argonne-national-laboratory/homebrew-hompack`
- `homebrew-cask-drivers` (official)
- Any third-party tap on GitHub

The `homebrew-` prefix is a **universal convention** because Homebrew's name resolution requires it.

---

## Implementation Summary

### Quick Setup

```bash
# 1. Create new GitHub repo: bhavpreet/homebrew-soundvibe

# 2. Clone locally
git clone https://github.com/bhavpreet/homebrew-soundvibe.git
cd homebrew-soundvibe

# 3. Create structure
mkdir -p Casks Formulas

# 4. Add cask definition
# (Use template above)
cat > Casks/soundvibe.rb << 'EOF'
[cask definition here]
EOF

# 5. Commit
git add Casks/
git commit -m "Initial cask definition for SoundVibe v1.0.0"
git push origin main

# 6. Test
brew tap bhavpreet/soundvibe
brew install --cask soundvibe
```

### Testing Checklist

- [ ] Create `homebrew-soundvibe` repo on GitHub
- [ ] Create `Casks/soundvibe.rb` with correct metadata
- [ ] Set version, SHA256, and URL
- [ ] Push to main branch
- [ ] Make repo public
- [ ] Test tap: `brew tap bhavpreet/soundvibe`
- [ ] Verify: `brew install --cask soundvibe` works
- [ ] Verify app in `/Applications/SoundVibe.app`
- [ ] Test uninstall: `brew uninstall --cask soundvibe`
- [ ] Test zap: `brew uninstall --cask --zap soundvibe`
- [ ] Update SoundVibe README with install instructions

---

## Key Takeaway

**Do not try to embed the tap in the existing SoundVibe repository.**

Homebrew requires a separate repository with the `homebrew-` prefix in the name. This is a fundamental design choice of Homebrew, not something that can be worked around.

**The correct approach:**
1. Create `bhavpreet/homebrew-soundvibe` repository
2. Add `Casks/soundvibe.rb` with cask definition
3. Users: `brew tap bhavpreet/soundvibe && brew install --cask soundvibe`

---

## Apology

I apologize for the incorrect initial recommendation. The error message proved the approach wrong, and I should have researched Homebrew's actual behavior before suggesting it.

**This document contains the correct solution.**

