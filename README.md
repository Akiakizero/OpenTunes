# OpenTunes

> Nome provvisorio.

App macOS open source che mostra il brano in riproduzione (Apple Music, Spotify, YouTube nel browser e
qualsiasi player che pubblica il Now Playing di sistema) e permette di controllarlo.

**Stato: v0.1 in preparazione** — fase 1: menu bar, popover, finestra flottante, HUD, hotkey e notifiche.

## Funzioni

- **Menu bar**: copertina, titolo con formato personalizzabile (`{artist} — {title}`, solo titolo, …) che scorre
  se è troppo lungo, pulsanti. Elementi riordinabili, controlli anche come elemento separato.
  Modalità compatta automatica quando lo spazio accanto al notch non basta.
- **Azioni del mouse** configurabili: clic sinistro (player), centrale (play/pausa), destro (menu rapido), rotella (volume o seek).
- **Popover**: copertina grande, avanzamento con seek, shuffle/repeat, volume, ultimi brani ascoltati.
- **Finestra flottante** Liquid Glass tinta con il colore della copertina, compatta o grande, sempre in primo piano.
- **HUD** al cambio brano e volume, **notifiche** con copertina, **scorciatoie globali**, avvio al login.
- Player da ignorare (es. Zoom), pulizia dei titoli di YouTube, copertine mancanti cercate su iTunes (disattivabile).

Non affiliato a NepTunes né ad Apple.

## Installazione

Scarica il `.dmg` dalla [pagina delle release](../../releases), trascina OpenTunes in Applicazioni e,
finché l'app non è notarizzata, togli la quarantena:

```sh
xattr -dr com.apple.quarantine /Applications/OpenTunes.app
```

Con Homebrew (tap personale, vedi `packaging/homebrew/`): `brew install --cask <utente>/tap/opentunes`.

## Requisiti

- macOS 26 o successivo
- Xcode 26 o successivo, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

```sh
xcodegen generate
xcodebuild -scheme OpenTunes -destination 'platform=macOS' test
```

La build compila automaticamente l'adapter MediaRemote dai sorgenti in `Vendor/mediaremote-adapter/`.
`scripts/make-dmg.sh` crea il `.dmg` in `dist/`; il workflow `Release` lo allega alla release a ogni tag `v*`.

## Come funziona

Da macOS 15.4 le app di terze parti non possono più leggere direttamente il Now Playing di sistema.
OpenTunes usa [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), che passa da
`/usr/bin/perl`. Se l'adapter non funziona, l'app passa da sola ad AppleScript per Apple Music e Spotify
(e chiede il permesso Automazione).

## Licenza

GPL-3.0-or-later. Vedi [LICENSE](LICENSE) e [CREDITS.md](CREDITS.md).
