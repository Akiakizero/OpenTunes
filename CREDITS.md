# Crediti

Codice di terzi incluso in OpenTunes. Aggiornare questo file nella stessa PR in cui entra codice nuovo.

| Componente | Progetto | Licenza | Dove | Note |
| --- | --- | --- | --- | --- |
| KeyboardShortcuts (dipendenza Swift Package, scorciatoie globali) | [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — Copyright (c) Sindre Sorhus | MIT | risolta da SPM (`project.yml`, ≥ 3.1.0) | non copiata nel repository |
| Forma del notch (`NotchShape`) e misura del notch da `auxiliaryTopLeftArea`/`auxiliaryTopRightArea` (`NotchGeometry`) | [MrKai77/DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) — Copyright (c) 2025 Kai Azim | MIT | `Sources/App/Notch/NotchShape.swift`, `Sources/App/Notch/NotchGeometry.swift` | adattati dal commit `cd0b3e5` (v1.1.0); il resto del player nel notch è scritto da zero (vedi sotto) |
| Sparkle (dipendenza Swift Package, aggiornamenti automatici) | [sparkle-project/Sparkle](https://github.com/sparkle-project/Sparkle) — Copyright (c) 2006-2013 Andy Matuschak e altri | MIT (con componenti di terzi elencati nel suo LICENSE) | risolta da SPM (`project.yml`, ≥ 2.6.0) | non copiata nel repository |
| mediaremote-adapter (script, framework, test client) | [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) — Copyright (c) 2025 Jonas van den Berg and contributors | BSD-3-Clause | `Vendor/mediaremote-adapter/` (vedi `VENDORING.md`) | sorgenti copiati senza modifiche al commit `14eed93`; compilati da `scripts/build-mediaremote-adapter.sh` |

## Idee e tecniche studiate (nessun codice copiato)

- Controllo del permesso Automazione con `AEDeterminePermissionToAutomateTarget`: tecnica vista in
  [PlayStatus](https://github.com/nbolar/playstatus) (MIT); la nostra implementazione è scritta da zero.
- Flusso `test` → `stream` → fallback AppleScript: visto in [Boring Notch](https://github.com/TheBoredTeam/boring.notch) (GPL-3.0).
- Ricerca delle copertine mancanti sull'iTunes Search API: idea vista in [PlayStatus](https://github.com/nbolar/playstatus) (MIT);
  implementazione scritta da zero (`ArtworkLookup`).
- Funzioni della menu bar (azioni del mouse, testo scorrevole, blacklist dei player, sezioni delle impostazioni):
  idee da [media-controls](https://github.com/sakithb/media-controls) (MIT); nessun codice copiato.
- Pulizia dei titoli dei browser (`TitleNormalizer`): regole scritte da zero, ispirate dal comportamento di
  [web-scrobbler](https://github.com/web-scrobbler/web-scrobbler) (MIT).
- Layout di popover, finestra flottante, HUD e impostazioni: riferimento visivo agli screenshot pubblici di NepTunes
  (solo proporzioni e disposizione; nessun asset, icona o testo copiato).

- Firma e chiamate dell'API Last.fm (`LastFMClient`): struttura studiata da `WebService.swift` di
  [Audioscrobbler](https://github.com/heyvito/audioscrobbler) (MIT) e dalla documentazione di Last.fm; codice scritto da zero.
- Regole di scrobbling (30 s, 50 %, 240 s) e pulizia dei titoli per gli scrobble (`ScrobbleRules`, `TitleCleaner`):
  comportamento di [web-scrobbler](https://github.com/web-scrobbler/web-scrobbler) (MIT); regole scritte da zero.
- Coda offline con nuovi tentativi: idea da [foo_scrobbler_mac](https://github.com/zfoxer/foo_scrobbler_mac) (MIT);
  filtro dei player con browser esclusi: idea da [osx-scrobbler](https://github.com/theli-ua/osx-scrobbler) (Apache-2.0).
  Nessun codice copiato.

- Player nel notch (stati chiuso/aperto, ali ai lati del notch, pannello sopra la menu bar, capsula sugli schermi
  senza notch): comportamento studiato da [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) (MIT),
  [Boring Notch](https://github.com/TheBoredTeam/boring.notch) (GPL-3.0) e
  [DynamicNotch](https://github.com/jackson-storm/DynamicNotch) (GPL-3.0). DynamicNotchKit non è usato come dipendenza:
  la sua API si basa su `ObservableObject`/Combine e la variante flottante usa `NSVisualEffectView`, mentre il progetto
  usa `@Observable` e solo il vetro di sistema. Nessun codice copiato oltre a quello indicato nella tabella.

- Testi sincronizzati: API pubblica di [LRCLIB](https://lrclib.net) (`/api/get`, poi `/api/search`; server MIT) chiamata
  da `LyricsService`. Il parser LRC (`LRCParser`) è scritto da zero dal formato documentato; l'idea di un parser
  minimale viene da `SyncedLyricsParser` di [Mooziac](https://github.com/shirkeharsh/mooziac) (MIT). Nessun codice copiato.
- Link universale: API pubblica di [Odesli / song.link](https://odesli.co) a partire dal link di Apple Music trovato
  sull'iTunes Search API (`ShareLinkService`). Nessun codice di terzi.
- Spettro del visualizer (`AudioSpectrum`, `SpectrumAnalyzer`): porting in Swift dell'algoritmo di `cavacore.c` di
  [cava](https://github.com/karlstav/cava) (MIT, testo della licenza sotto): bande logaritmiche, equalizzazione
  `frequenza^0.85`, sensibilità automatica, caduta «a gravità» e filtro integrale con le stesse costanti. Cattura
  con Core Audio (process tap) e FFT con Accelerate scritte da zero. Barre in stile Dynamic Island disegnate da zero.
- Discord Rich Presence (`DiscordIPC`): protocollo IPC locale documentato da Discord, scritto da zero; l'idea viene
  da [applemusicrp](https://github.com/wxllow/applemusicrp), di cui non si usa codice.
- Server compatibili con ListenBrainz: API di [Maloja](https://github.com/krateng/maloja) (`/apis/listenbrainz/1/`).
- Animazione di ripiego del visualizer (`VisualizerBars`): animazione decorativa come in [Boring Notch](https://github.com/TheBoredTeam/boring.notch)
  (GPL-3.0), scritta da zero con `Canvas` e somme di seni; uscita audio e volume del player come in
  [Tuneful](https://github.com/martinfekete10/Tuneful) 1.x (MIT), scritti da zero con Core Audio e AppleScript.

L'analisi completa dei progetti di riferimento è in `docs/analisi/`.

## Testo della licenza MIT di cava

```
MIT License

Copyright (c) 2015 Karl Stavestrand

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Testo della licenza MIT di DynamicNotchKit

```
MIT License

Copyright (c) 2025 Kai Azim

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
