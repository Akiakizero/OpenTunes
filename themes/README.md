<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# Temi

Temi per OpenTunes da importare in Impostazioni › Integrazioni › Temi › «Importa tema JSON…».
Tutti usano il vetro di sistema (Liquid Glass): il tema sceglie solo la variante del vetro e i colori.

| Campo | Valori | Obbligatorio |
| --- | --- | --- |
| `name` | nome mostrato nelle impostazioni | sì |
| `glass` | `regular` (più leggibile) o `clear` (più trasparente) | no, `regular` |
| `tint` | `#RRGGBB`, `artwork` (colore della copertina) o assente (vetro senza tinta) | no |
| `tintOpacity` | da `0` a `1` | no, `0.35` |
| `accent` | `#RRGGBB` per pulsanti e barre | no |

```json
{ "name": "Tramonto", "glass": "regular", "tint": "#FF7A45", "tintOpacity": 0.3, "accent": "#FFB000" }
```

Per proporre un tema apri una PR con il file (nome in minuscolo, es. `mio-tema.json`) e uno screenshot.
