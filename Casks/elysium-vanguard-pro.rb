cask "elysium-vanguard-pro" do
  version "16.0"
  sha256 :no_check

  url "https://github.com/jordelmir/ElysiumVanguard8K/releases/download/v#{version}/ElysiumVanguardPro_#{version}_Mac.dmg"
  name "Elysium Vanguard Pro Player 8K"
  desc "Ultimate 8K Video + High-Fidelity Music dual-engine suite"
  homepage "https://github.com/jordelmir/ElysiumVanguard8K"

  app "Elysium Vanguard Pro Player 8K.app"

  zap trash: [
    "~/Library/Preferences/com.jordelmir.ElysiumVanguardProPlayer8K.plist",
    "~/Library/Saved Application State/com.jordelmir.ElysiumVanguardProPlayer8K.savedState",
  ]
end
