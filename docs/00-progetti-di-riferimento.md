# Progetti open-source di riferimento — download e analisi

> **Istruzione per Claude Code:** prima di scrivere codice per la fase 0, scarica il codice sorgente di **tutti** i progetti elencati qui sotto e analizzali uno per uno, seguendo la procedura in fondo al file. Il risultato dell'analisi guida tutte le fasi successive.

## Regole

1. I sorgenti vanno in `reference/`, che è nel `.gitignore`: **non vanno mai committati** nel repo del progetto.
2. Il codice scaricato serve per leggere, non per eseguire: **non lanciare** script, build, `npm install`, `make` o simili dentro `reference/`.
3. Si copia codice solo da progetti con licenza **MIT, BSD, Apache-2.0 o GPL-3**. Per i progetti senza licenza dichiarata: solo studio, nessuna copia.
4. Ogni volta che entra codice di un altro progetto, si aggiorna `CREDITS.md` nella stessa PR.

## Elenco completo

> Licenze **verificate dal file LICENSE** il 2026-11-12 — dettagli in `docs/analisi/SINTESI.md`.

| # | Categoria | Progetto | Repository | Fase | Licenza verificata |
| --- | --- | --- | --- | --- | --- |
| 1 | Dati Now Playing | mediaremote-adapter | https://github.com/ungive/mediaremote-adapter | 0 | BSD-3 |
| 2 | Dati Now Playing | mediaremote-adapter (Swift package) | https://github.com/ejbills/mediaremote-adapter | 0 | BSD-3 |
| 3 | Notch | Boring Notch | https://github.com/TheBoredTeam/boring.notch | 0, 1, 3, 4 | GPL-3 |
| 4 | Notch | DynamicNotchKit | https://github.com/MrKai77/DynamicNotchKit | 3 | MIT |
| 5 | Notch | DynamicNotch | https://github.com/jackson-storm/DynamicNotch | 3 | GPL-3 |
| 6 | Notch | NotchDrop | https://github.com/Lakr233/NotchDrop | 3 | MIT |
| 7 | Menu bar | SpotMenu | https://github.com/kmikiy/SpotMenu | 1 | MIT |
| 8 | Menu bar | media-controls (GNOME) | https://github.com/sakithb/media-controls | 1 | MIT |
| 9 | Menu bar | PlayStatus | https://github.com/nbolar/playstatus | 1 | MIT |
| 10 | Menu bar | MusicMenu | https://github.com/niklhut/MusicMenu | 0, 1 | GPL-3 |
| 11 | Menu bar | NowPlayingMenuBar | https://github.com/TrevorBurnham/NowPlayingMenuBar | 1 | MIT |
| 12 | Menu bar | MusicBar | https://github.com/dimitarnestorov/MusicBar | 1 | EUPL-1.2 (no copia) |
| 13 | Menu bar | Spotify Now Playing | https://github.com/abeljohn/spotify-now-playing (confermato) | 1 | MIT |
| 14 | Menu bar | nowspot | https://github.com/saivittalb/nowspot | 1 | Apache-2.0 |
| 15 | Menu bar | cbNP | https://github.com/EnjoyBacon7/cbNP | 1 | nessuna (no copia) |
| 16 | Menu bar | barik (modulo Now Playing) | https://github.com/xxspell/barik | 1 | MIT |
| 17 | Menu bar | Spotbar | https://github.com/levarr/Spotbar | 1 | MIT |
| 18 | Menu bar | Menu Bar Ticker | https://github.com/serban/menubar-ticker | 1 | MIT |
| 19 | Menu bar | SoundSeer | https://github.com/jonathangarelick/SoundSeer | 1, 4 | nessuna (no copia) |
| 20 | Mini player | Tuneful | https://github.com/martinfekete10/Tuneful | 1, 3, 4 | **nessuna: sorgenti rimossi** (no copia) |
| 21 | Mini player | Now Playing | https://github.com/dd00031/now-playing | 1 | GPL-3 |
| 22 | Player | Mooziac | https://github.com/shirkeharsh/mooziac | 3, 4 | MIT |
| 23 | Scrobbling | osx-scrobbler | https://github.com/theli-ua/osx-scrobbler | 0, 2 | Apache-2.0 |
| 24 | Scrobbling | Audioscrobbler | https://github.com/heyvito/audioscrobbler | 2 | MIT |
| 25 | Scrobbling | goscrobble | https://github.com/p-mng/goscrobble | 2, 5 | MIT |
| 26 | Scrobbling | web-scrobbler | https://github.com/web-scrobbler/web-scrobbler | 2 | MIT |
| 27 | Scrobbling | foo_scrobbler_mac | https://github.com/zfoxer/foo_scrobbler_mac | 2 | **MIT** |
| 28 | Scrobbling | Sidra | https://github.com/wimpysworld/sidra | 2 | Blue Oak 1.0.0 (fuori lista) |
| 29 | Altro | applemusicrp | https://github.com/wxllow/applemusicrp | 5 | MIT |
| 30 | Altro | GoPlaying | https://github.com/justinmdickey/goplaying | 3, 5 | MIT |
| 31 | Libreria | KeyboardShortcuts | https://github.com/sindresorhus/KeyboardShortcuts | 1 | MIT |
| 32 | Libreria | Sparkle | https://github.com/sparkle-project/Sparkle | 4 | MIT |
| 33 | Servizio | LRCLIB | https://github.com/tranxuanthang/lrclib | 4 | MIT |

Odesli/song.link è solo un'API pubblica: non c'è codice da scaricare.

## Script di download

Da lanciare nella cartella principale del repo:

```bash
#!/usr/bin/env bash
# scripts/fetch-references.sh — scarica i sorgenti dei progetti di riferimento
set -euo pipefail

mkdir -p reference
grep -qxF 'reference/' .gitignore 2>/dev/null || echo 'reference/' >> .gitignore

repos=(
  ungive/mediaremote-adapter
  ejbills/mediaremote-adapter
  TheBoredTeam/boring.notch
  MrKai77/DynamicNotchKit
  jackson-storm/DynamicNotch
  Lakr233/NotchDrop
  kmikiy/SpotMenu
  sakithb/media-controls
  nbolar/playstatus
  niklhut/MusicMenu
  TrevorBurnham/NowPlayingMenuBar
  dimitarnestorov/MusicBar
  abeljohn/spotify-now-playing
  saivittalb/nowspot
  EnjoyBacon7/cbNP
  xxspell/barik
  levarr/Spotbar
  martinfekete10/Tuneful
  dd00031/now-playing
  theli-ua/osx-scrobbler
  heyvito/audioscrobbler
  p-mng/goscrobble
  web-scrobbler/web-scrobbler
  zfoxer/foo_scrobbler_mac
  wimpysworld/sidra
  wxllow/applemusicrp
  sindresorhus/KeyboardShortcuts
  sparkle-project/Sparkle
)

for r in "${repos[@]}"; do
  dest="reference/${r//\//__}"
  if [ -d "$dest" ]; then
    echo "già presente: $r"
  else
    git clone --depth 1 "https://github.com/$r.git" "$dest" || echo "ERRORE: $r" >> reference/_errori.txt
  fi
done

echo "Fatto. Controlla reference/_errori.txt per i repository non scaricati."
```

**Dopo lo script**, i progetti segnati "da trovare" (Menu Bar Ticker, SoundSeer, Mooziac, GoPlaying, LRCLIB) vanno cercati: apri la pagina indicata, trova il link al repository GitHub, aggiungilo all'array `repos` e rilancia lo script.

## Procedura di analisi (per Claude Code)

Per **ogni** progetto in `reference/`, crea un file `docs/analisi/<nome-progetto>.md` con questa struttura:

```markdown
# <Nome progetto>

- **Repository:** <url>
- **Licenza (dal file LICENSE):** <licenza esatta> — si può copiare codice? sì / no
- **Linguaggio e framework:** <es. Swift + SwiftUI, Objective-C + AppKit, JavaScript GNOME Shell>
- **Ultimo commit:** <data>
- **Versione minima di macOS:** <se indicata>

## Come legge il brano in riproduzione
<MediaRemote, mediaremote-adapter, AppleScript, Web API… con i file esatti>

## Architettura
<moduli principali, come passa lo stato dalla sorgente alla UI>

## Interfaccia
<superfici: menu bar, popover, finestra, notch, widget; tecniche notevoli>

## Cosa riusare
| File / componente | Cosa fa | Dove serve da noi (fase) | Copia o solo studio |

## Cosa evitare
<problemi, bug noti nelle issue, scelte che non vogliamo ripetere>

## Note per il nostro progetto
<3–5 punti concreti>
```

Infine crea `docs/analisi/SINTESI.md` con:

1. **Tabella licenze**: progetto → licenza verificata → copia consentita sì/no
2. **Come ogni progetto legge il Now Playing** e quale approccio regge meglio su macOS 27
3. **Migliori componenti da riusare**, ordinati per fase
4. **Problemi ricorrenti** emersi da più progetti (permessi, copertine, notch, Spotify)
5. **Modifiche consigliate** al piano e ai file delle fasi

## Prompt da dare a Claude Code

> *"Leggi `docs/00-progetti-di-riferimento.md`. Esegui `scripts/fetch-references.sh`, poi trova i repository segnati 'da trovare' e scaricali. Analizza ogni progetto in `reference/` senza eseguire il loro codice, e scrivi un file in `docs/analisi/` per ognuno seguendo la struttura indicata. Verifica le licenze leggendo i file LICENSE, non il README. Alla fine scrivi `docs/analisi/SINTESI.md`. Lavora un progetto alla volta e fermati dopo ogni 5 progetti per farmi vedere i risultati."*

Per i progetti grandi (Boring Notch, Sparkle, web-scrobbler) conviene chiedere un'analisi mirata: solo le cartelle che riguardano media, menu bar, notch o scrobbling.
