# DynamicNotch (jackson-storm)

- **Repository:** https://github.com/jackson-storm/DynamicNotch
- **Licenza (dal file LICENSE):** GPL-3.0 — si può copiare codice? **sì**
- **Linguaggio e framework:** Swift + SwiftUI (466 file Swift), progetto grande
- **Ultimo commit:** 2026-11-10
- **Versione minima di macOS:** non verificata

## Come legge il brano in riproduzione
Analisi mirata a `DynamicNotch/Features/NowPlaying/`:
- `Services/MediaRemoteNowPlayingService.swift` — adapter ungive con `stream --no-diff --debounce=35 --micros`;
  in caso di terminazione con codice ≠ 0 **riprogramma il riavvio** (`scheduleRestart`).
- `Services/MediaRemoteAdapterResources.swift` — risolve script/framework/test client in più cartelle del bundle
  (`Resources/MediaRemoteAdapter/`) e costruisce gli argomenti.
- `Services/NowPlayingApplicationBridge.swift` — AppleScript per Music/Spotify/YouTube Music (th-ch) per
  stato preferito, shuffle, repeat; aggiornamento ottimistico dopo un comando.
- `Models/NowPlayingSourceFilter.swift` — filtro per sorgente (Music+iTunes, Spotify, YouTube Music).

## Architettura
Servizio (protocollo `NowPlayingMonitoring`) → `NowPlayingViewModel` → contenuto del notch.
Servizi "Inactive*" come null object.

## Interfaccia
Notch con copertina, equalizzatore leggero, palette dalla copertina, selettore uscita audio.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `MediaRemoteAdapterResources` | percorsi assoluti delle risorse | 0 — `AdapterResources` | Studio/copia (GPL-3) |
| Aggiornamento ottimistico dopo play/pausa | UI reattiva | 1 | Studio |
| `NowPlayingArtworkPalette`, `AudioOutputRoutePickerButton` | palette, AirPlay | 3–4 | Studio |
| Null object `Inactive*Service` | sorgente disattivata | 0 | Studio |

## Cosa evitare
- Riavvio automatico dopo exit ≠ 0: contrario al README dell'adapter.
- `--no-diff` + artwork: molti dati a ogni evento.

## Note per il nostro progetto
1. Struttura `Resources/MediaRemoteAdapter/` uguale a quella prevista nel nostro piano.
2. `--debounce` piccolo (30–50 ms) riduce le raffiche di aggiornamenti.
