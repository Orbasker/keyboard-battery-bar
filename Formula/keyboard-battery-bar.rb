class KeyboardBatteryBar < Formula
  desc "Menu bar battery level for Bluetooth keyboards, plus a CLI"
  homepage "https://github.com/Orbasker/keyboard-battery-bar"
  url "https://github.com/Orbasker/keyboard-battery-bar/archive/refs/tags/v1.2.tar.gz"
  sha256 "e96a5fcb78f252003b44b3498de2694491db6dd9229cdb0fb6cd292a835a98ea"
  license "MIT"

  depends_on xcode: :build
  depends_on :macos

  def install
    system "./build.sh", "#{prefix}/Keyboard Battery Bar.app"
    bin.install "build/keyboard-battery"
  end

  def caveats
    <<~EOS
      The app was built at:
        #{prefix}/Keyboard Battery Bar.app

      Link it into your Applications folder and start it at login:
        ln -sfn "#{prefix}/Keyboard Battery Bar.app" ~/Applications/
        "#{prefix}/Keyboard Battery Bar.app/Contents/MacOS/KeyboardBatteryBar" &

      Reading a keyboard's battery opens its HID device, which macOS gates behind
      Input Monitoring. Add the app under System Settings > Privacy & Security >
      Input Monitoring, then quit and reopen it. Until then it shows an orange "!".
    EOS
  end

  test do
    assert_match "battery", shell_output("#{bin}/keyboard-battery --help")
  end
end
