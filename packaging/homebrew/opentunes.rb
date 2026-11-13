# SPDX-License-Identifier: GPL-3.0-or-later
# Cask per il tap personale. Va copiato in un repository `homebrew-tap` come `Casks/opentunes.rb`;
# a ogni release aggiornare `version` e `sha256` (il valore è nel file .dmg.sha256 della release).
# Sostituire UTENTE con il nome dell'account GitHub.
cask "opentunes" do
  version "0.2.0"
  sha256 "SOSTITUIRE_CON_SHA256_DEL_DMG"

  url "https://github.com/UTENTE/OpenTunes/releases/download/v#{version}/OpenTunes-#{version}.dmg"
  name "OpenTunes"
  desc "Brano in riproduzione in menu bar, finestra flottante e HUD"
  homepage "https://github.com/UTENTE/OpenTunes"

  depends_on macos: ">= :tahoe"

  app "OpenTunes.app"

  # L'app non è notarizzata: si toglie la quarantena dopo l'installazione.
  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/OpenTunes.app"]
  end

  zap trash: [
    "~/Library/Preferences/org.opentunes.OpenTunes.plist",
  ]
end
