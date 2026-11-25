cask "core-monitor" do
  version "17.0.5"
  sha256 "ffd20ac98b73396f8bbbee787d45931f71e16fef4614046098696bf0de18a931"

  url "https://github.com/offyotto/Core-Monitor/releases/download/v17.0.5/Core-Monitor.app.zip",
      verified: "github.com/offyotto/Core-Monitor/"
  name "Core-Monitor"
  desc "Native Apple Silicon system monitor with menu bar stats, alerts, and SMC-backed fan control"
  homepage "https://xnu.is-a.dev/"

  depends_on arch: :arm64
  depends_on macos: ">= :ventura"

  app "Core-Monitor.app"

  zap trash: [
    "~/Library/Application Support/Core-Monitor",
    "~/Library/Caches/Core-Monitor",
    "~/Library/Preferences/CoreTools.Core-Monitor.plist",
    "~/Library/Saved Application State/CoreTools.Core-Monitor.savedState"
  ]
end
