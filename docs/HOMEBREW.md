# Installing SoundVibe via Homebrew

SoundVibe can be installed using [Homebrew](https://brew.sh/), the popular package
manager for macOS.

## Quick Install

```bash
brew tap bhavpreet/soundvibe
brew install --cask soundvibe
```

## Alternative: Manual Installation

If you prefer not to use Homebrew:

1. Download the latest `SoundVibe.dmg` from
   [GitHub Releases](https://github.com/bhavpreet/SoundVibe/releases)
2. Open the DMG file
3. Drag `SoundVibe.app` to your Applications folder
4. Launch SoundVibe from Applications

## Updating

```bash
brew upgrade --cask soundvibe
```

## Uninstalling

```bash
brew uninstall --cask soundvibe
```

To also remove user data and preferences:

```bash
brew uninstall --cask --zap soundvibe
```

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** (M1/M2/M3) — native ARM64 binary
- **Homebrew** installed ([install instructions](https://brew.sh/))

## Gatekeeper Warning

If you see "Apple could not verify" warning when first launching SoundVibe:

1. Open **System Settings** → **Privacy & Security**
2. Scroll to "Security" section
3. Click **Open Anyway** next to the SoundVibe message

Or via Terminal:

```bash
xattr -cr /Applications/SoundVibe.app
```

This is because SoundVibe uses ad-hoc code signing. The app is open source and
safe to use.

## Setting Up Your Own Homebrew Tap

If you want to distribute SoundVibe via your own Homebrew tap:

### 1. Create the Tap Repository

Create a new GitHub repository named `homebrew-soundvibe`:

```
homebrew-soundvibe/
├── Casks/
│   └── soundvibe.rb
├── README.md
└── LICENSE
```

### 2. Copy the Cask Definition

Copy `Casks/soundvibe.rb` from this repository to your tap's `Casks/` directory.

### 3. Create a Release

1. Tag a release: `git tag v1.0.0 && git push --tags`
2. GitHub Actions will build the DMG and create a release
3. Update the cask's `sha256` with the hash from the release notes

### 4. Test Your Tap

```bash
# Add your tap
brew tap yourusername/soundvibe

# Install
brew install --cask soundvibe

# Verify
ls -la /Applications/SoundVibe.app
```

## Troubleshooting

### "No available cask" error

Make sure you've added the tap first:

```bash
brew tap bhavpreet/soundvibe
```

### Hash mismatch error

The DMG may have been updated. Try:

```bash
brew update
brew reinstall --cask soundvibe
```

### App won't open

Check Gatekeeper settings (see above) or verify the app:

```bash
codesign -vvv /Applications/SoundVibe.app
```

## Building from Source

For developers who want to build from source instead:

```bash
git clone https://github.com/bhavpreet/SoundVibe.git
cd SoundVibe
swift build -c release
bash scripts/make-dmg.sh
```

The DMG will be created at `dist/SoundVibe.dmg`.
