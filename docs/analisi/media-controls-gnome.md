# media-controls (GNOME Shell)

- **Repository:** https://github.com/sakithb/media-controls
- **Licenza (dal file LICENSE):** MIT — si può copiare codice? **sì** (ma è JavaScript per GNOME, utile solo come idea)
- **Linguaggio e framework:** JavaScript, estensione GNOME Shell
- **Ultimo commit:** 2026-04-22
- **Versione minima di macOS:** n/a (Linux)

## Come legge il brano in riproduzione
D-Bus MPRIS: `src/helpers/shell/PlayerProxy.js` crea proxy per `org.mpris.MediaPlayer2.Player`
e ascolta `PropertiesChanged` (eventi, niente polling).

## Architettura
Un `PlayerProxy` per ogni bus name MPRIS → `extension.js` sceglie il player attivo → `PanelButton`.

## Interfaccia
Pulsante nel pannello con etichetta scorrevole (`ScrollingLabel.js`), menu con slider
(`MenuSlider.js`), preferenze per larghezza, elementi visibili, blacklist dei player.

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |
| --- | --- | --- | --- |
| `ScrollingLabel.js` | testo che scorre a larghezza fissa | 1 | Studio |
| Preferenze (ordine elementi, larghezza max, blacklist player) | personalizzazione menu bar | 1 | Studio |
| Selezione del player attivo tra più sorgenti | priorità | 0 — `NowPlayingStore` | Studio |

## Cosa evitare
- Nulla di specifico per macOS.

## Note per il nostro progetto
1. Modello ad eventi come MPRIS: il nostro `AsyncStream` per sorgente ne è l'equivalente.
2. Blacklist dei player utile già nel modello `PlayerApp`.
