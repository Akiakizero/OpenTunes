# Sintesi dell'analisi dei progetti di riferimento

Data: 2026-11-12 · Progetti analizzati: 33 (28 dall'elenco + 5 "da trovare") · Codice in `reference/` (non committato, nulla è stato eseguito).

## Repository "da trovare": cosa è stato trovato

| Progetto | Repository trovato | Come |
| --- | --- | --- |
| Menu Bar Ticker | https://github.com/serban/menubar-ticker | ricerca web (AlternativeTo / ecosyste.ms) |
| SoundSeer | https://github.com/jonathangarelick/SoundSeer | ricerca web (Product Hunt / relatedrepos) |
| Mooziac | https://github.com/shirkeharsh/mooziac | API di ricerca GitHub (`q=mooziac`) |
| GoPlaying | https://github.com/justinmdickey/goplaying | articolo LinuxLinks + pacchetto AUR |
| LRCLIB | https://github.com/tranxuanthang/lrclib | ricerca web (server di lrclib.net) |

Tutti e cinque sono aggiunti a `scripts/fetch-references.sh`.

## 1. Tabella licenze (verificate dal file LICENSE)

| # | Progetto | Licenza verificata | Copia consentita | Nota rispetto al file 00 |
| --- | --- | --- | --- | --- |
| 1 | mediaremote-adapter (ungive) | BSD-3-Clause | sì | = |
| 2 | mediaremote-adapter (ejbills) | BSD-3-Clause | sì | = |
| 3 | Boring Notch | GPL-3.0 | sì | = |
| 4 | DynamicNotchKit | MIT | sì | = |
| 5 | DynamicNotch | GPL-3.0 | sì | = |
| 6 | NotchDrop | MIT | sì | risolto (era "da verificare") |
| 7 | SpotMenu | MIT | sì | = |
| 8 | media-controls (GNOME) | MIT | sì | = |
| 9 | PlayStatus | MIT | sì | risolto |
| 10 | MusicMenu | GPL-3.0 | sì | risolto |
| 11 | NowPlayingMenuBar | MIT | sì | = |
| 12 | MusicBar | **EUPL-1.2** | **no** | risolto: licenza fuori lista |
| 13 | Spotify Now Playing | MIT | sì | = (repo confermato) |
| 14 | nowspot | Apache-2.0 | sì | risolto |
| 15 | cbNP | **nessuna** | **no** | risolto: solo studio |
| 16 | barik | MIT | sì | risolto |
| 17 | Spotbar | MIT | sì | risolto |
| 18 | Menu Bar Ticker | MIT | sì | = |
| 19 | SoundSeer | **nessuna** | **no** | risolto: solo studio |
| 20 | Tuneful | **nessuna — sorgenti rimossi** | **no** | **cambiato**: era MIT, ora il repo ha solo il README |
| 21 | Now Playing (dd00031) | GPL-3.0 | sì | = |
| 22 | Mooziac | MIT (include uBlock Origin Lite GPL-3 nelle risorse) | sì | risolto |
| 23 | osx-scrobbler | Apache-2.0 | sì | risolto |
| 24 | Audioscrobbler | MIT | sì | = |
| 25 | goscrobble | MIT | sì | = |
| 26 | web-scrobbler | MIT | sì | risolto |
| 27 | foo_scrobbler_mac | **MIT** | sì | **corretto**: il file 00 diceva GPL-3 |
| 28 | Sidra | **Blue Oak Model 1.0.0** | **no** (fuori lista: serve decisione) | risolto |
| 29 | applemusicrp | MIT | sì | risolto |
| 30 | GoPlaying | MIT | sì | risolto |
| 31 | KeyboardShortcuts | MIT | sì | = |
| 32 | Sparkle | MIT | sì | = |
| 33 | LRCLIB | MIT | sì | risolto |

Apache-2.0 e GPL-3.0-or-later sono compatibili (Apache-2.0 → GPL-3 sì). Blue Oak ed EUPL-1.2 sono
permissive/compatibili con la GPL, ma la regola del progetto le esclude: lasciate a decisione del maintainer.

## 2. Come ogni progetto legge il Now Playing

| Approccio | Progetti | Su macOS 27 |
| --- | --- | --- |
| **Adapter Perl** (`/usr/bin/perl` + framework, `stream`) | Boring Notch, DynamicNotch, cbNP, dd00031 (con `get`), ejbills; barik e goscrobble via CLI `media-control`; GoPlaying con helper proprio | **funziona** — verificato da noi su 27.2.1 con Musica e YouTube in Safari (il primo `test` a freddo può uscire con 4: ritentare) |
| MediaRemote in-process | NowPlayingMenuBar, osx-scrobbler (crate), comandi di Boring Notch | **lettura non funziona da 15.4** |
| AppleScript + notifiche distribuite | PlayStatus, SpotMenu, MusicMenu, SoundSeer, Ticker, Spotify Now Playing, nowspot, MusicBar, Audioscrobbler, applemusicrp | funziona solo per Music e Spotify; richiede permesso Automazione |
| Web API / DOM | Spotbar (Spotify Web API), web-scrobbler (DOM), Sidra (MusicKit JS) | indipendente dal sistema, ma un player alla volta |
| Player che pubblica il proprio stato | Mooziac (`MPNowPlayingInfoCenter`) | — |
| Linux (MPRIS/playerctl) | media-controls, goscrobble, GoPlaying | n/a |

**Approccio scelto:** adapter ungive in `stream --micros` come sorgente primaria (copre tutti i player,
browser inclusi); `test` all'avvio; se fallisce o il processo termina con codice ≠ 0 → `AppleScriptSource`
(Music + Spotify), attivata dalle notifiche distribuite `com.apple.Music.playerInfo`,
`com.apple.iTunes.playerInfo`, `com.spotify.client.PlaybackStateChanged` con un polling lento di sicurezza.
YouTube nel browser è raggiungibile **solo** dall'adapter: senza adapter non c'è fallback (limite noto).

## 3. Migliori componenti da riusare, per fase

**Fase 0**
- ungive/mediaremote-adapter: script `.pl` + sorgenti del framework e del test client (BSD-3), compilati da noi.
- PlayStatus: `AEDeterminePermissionToAutomateTarget` per lo stato del permesso Automazione (MIT).
- Boring Notch: flusso `test` → `stream` → fallback (studio).
- DynamicNotch: risoluzione dei percorsi `Resources/MediaRemoteAdapter/` (studio).
- MusicMenu: `project.yml` XcodeGen (studio).
- cbNP: file `VENDORING.md` con commit e data della copia (idea).

**Fase 1** — media-controls (testo scorrevole, preferenze), SpotMenu (slider), PlayStatus
(`ITunesArtworkLookup` per copertine mancanti), KeyboardShortcuts (dipendenza), NowPlayingMenuBar (`SMAppService`),
SoundSeer (azioni "copia link").

**Fase 2** — Audioscrobbler `WebService.swift` (firma Last.fm, MIT), web-scrobbler (regole 30 s/50 %/240 s e
regex di normalizzazione, MIT), foo_scrobbler_mac (coda offline), osx-scrobbler (filtro app + prompt),
Sidra (gestione `ignoredMessage`, solo studio).

**Fase 3** — DynamicNotchKit (dipendenza MIT), NotchDrop (`NotchWindow`, `EventMonitors`, MIT),
Boring Notch (finestra SkyLight, `NotchShape`, GPL-3).

**Fase 4** — Mooziac `SyncedLyricsParser` (MIT) + API LRCLIB `/api/get` → `/api/search`, Sparkle.

**Fase 5** — goscrobble (sink CSV, ListenBrainz), applemusicrp (Discord), ejbills (processo persistente con comandi su stdin).

## 4. Problemi ricorrenti

1. **Permessi Automazione**: `tell application` avvia il player se è chiuso → controllare sempre che sia in
   esecuzione; `AEDeterminePermissionToAutomateTarget` è bloccante; chiedere il permesso solo su azione dell'utente.
2. **Copertine**: con `get` arrivano in ritardo (usare `stream`); Spotify via AppleScript dà solo un URL;
   l'artwork può sparire per un attimo durante il seek (l'adapter lo corregge in `stream`); payload base64 grandi.
3. **Parsing dello stream**: due progetti convertono i chunk in `String` e perdono dati con UTF-8 spezzato;
   Boring Notch non rimuove le chiavi `null` nei diff.
4. **Riavvio dell'adapter**: DynamicNotch ed ejbills riavviano il processo; il README dice di non farlo.
5. **Spotify**: `duration` in millisecondi da AppleScript; nessuna copertina binaria; Web API solo per extra.
6. **Notifica di Music**: nomi diversi nel tempo (`com.apple.iTunes.playerInfo`, `com.apple.Music.playerInfo`) → osservarli entrambi.
7. **Concorrenza**: `NSAppleScript` usato da thread concorrenti; callback + `DispatchQueue` ovunque.
8. **Polling**: SpotMenu (2 s), Audioscrobbler (1 s), dd00031 (`get`) — da evitare.
9. **Notch**: API private SkyLight in Boring Notch; DynamicNotchKit/NotchDrop usano solo API pubbliche.

## 5. Modifiche consigliate al piano

- **File 00**: aggiornare le licenze (Tuneful senza sorgenti, foo_scrobbler_mac MIT, MusicBar EUPL, Sidra Blue Oak,
  cbNP/SoundSeer senza licenza) e i 5 repository trovati. *(Applicato.)*
- **Fase 0**: il link "ejbills/mediaremote-adapter" puntava a ungive. *(Corretto.)* Usare `stream --micros`.
  Non riavviare l'adapter dopo exit ≠ 0. Compilare l'adapter da sorgente fissato a un commit (`Vendor/`).
  Gate YouTube: valido solo con adapter attivo (nessun fallback per i browser). *(Annotato nel file.)*
- **Fase 1**: copertine Spotify da URL con cache; lookup iTunes per copertine mancanti; normalizzazione dei titoli YouTube.
- **Fase 2**: preferire Audioscrobbler `WebService` e le regole di web-scrobbler; coda offline; browser esclusi per default.
- **Fase 3**: preferire DynamicNotchKit/NotchDrop (MIT, API pubbliche) a SkyLight.
- **Fase 4**: Tuneful non è più consultabile come codice.
- **Decisione aperta**: ammettere o no Blue Oak ed EUPL-1.2 nella lista delle licenze copiabili.
