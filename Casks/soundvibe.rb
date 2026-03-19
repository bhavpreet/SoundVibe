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
