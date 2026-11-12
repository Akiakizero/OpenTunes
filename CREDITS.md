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

L'analisi completa dei progetti di riferimento è in `docs/analisi/`.
