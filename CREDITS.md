# Crediti

Codice di terzi incluso in OpenTunes. Aggiornare questo file nella stessa PR in cui entra codice nuovo.

| Componente | Progetto | Licenza | Dove | Note |
| --- | --- | --- | --- | --- |
| KeyboardShortcuts (dipendenza Swift Package, scorciatoie globali) | [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — Copyright (c) Sindre Sorhus | MIT | risolta da SPM (`project.yml`, ≥ 3.1.0) | non copiata nel repository |
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

L'analisi completa dei progetti di riferimento è in `docs/analisi/`.
