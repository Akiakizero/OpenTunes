# SPDX-License-Identifier: GPL-3.0-or-later
# Cask per il tap personale. Va copiato in un repository `homebrew-tap` come `Casks/opentunes.rb`;
# a ogni release aggiornare `version` e `sha256` (il valore è nel file .dmg.sha256 della release).
cask "opentunes" do
  version "0.3.0"
  sha256 "e11bc3859b7bce3d2892ed88c932afd42d9bce4256feb1b5bce9fc9d611863b7"

  url "https://github.com/Akiakizero/OpenTunes/releases/download/v#{version}/OpenTunes-#{version}.dmg"
  name "OpenTunes"
  desc "Brano in riproduzione in menu bar, notch, widget e finestra flottante"
  homepage "https://github.com/Akiakizero/OpenTunes"

  depends_on macos: ">= :tahoe"

  app "OpenTunes.app"

  # L'app non è notarizzata: si toglie la quarantena dopo l'installazione.
  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/OpenTunes.app"]
  end

  zap trash: [
    "~/Library/Application Support/OpenTunes",
    "~/Library/Group Containers/org.opentunes.shared",
    "~/Library/Preferences/org.opentunes.OpenTunes.plist",
  ]
end
