cask "core-monitor" do
  version :latest
  sha256 :no_check

  url "https://github.com/offyotto/Core-Monitor/releases/latest/download/Core-Monitor.app.zip",
      verified: "github.com/offyotto/Core-Monitor/"
  name "Core-Monitor"
  desc "Native Apple Silicon system monitor with menu bar stats, alerts, and SMC-backed fan control"
  homepage "https://offyotto.github.io/Core-Monitor/"

  depends_on arch: :arm64
  depends_on macos: ">= :monterey"

  app "Core-Monitor.app"

  zap trash: [
    "~/Library/Application Support/Core-Monitor",
    "~/Library/Caches/Core-Monitor",
    "~/Library/Preferences/CoreTools.Core-Monitor.plist",
    "~/Library/Saved Application State/CoreTools.Core-Monitor.savedState"
  ]
end
