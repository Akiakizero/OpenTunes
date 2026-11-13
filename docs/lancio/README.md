<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# Lancio v0.3 — bozze

Testi pronti per il lancio. Vanno pubblicati **a mano** dal maintainer, dopo la release `v0.3.0`:
nessuno di questi passi è automatico.

| Passo | File | Note |
| --- | --- | --- |
| Release `v0.3.0` e cask | `packaging/homebrew/opentunes.rb` | `git tag v0.3.0 && git push --tags` avvia il workflow; poi copiare `sha256` dal file `.dmg.sha256` nel cask del tap |
| Etichette del repository | `.github/labels.yml` | `scripts/sync-labels.sh` (richiede `gh auth login`); segnare 3–5 issue come «good first issue» |
| r/macapps | `reddit-macapps.md` | dichiarare di essere lo sviluppatore; al massimo un post ogni 30 giorni; megathread «App Pile» se il post principale non è ammesso |
| r/lastfm, r/opensource, r/swift | `reddit-altri.md` | taglio diverso per ogni community |
| AlternativeTo | `alternativeto.md` | scheda come alternativa a NepTunes |
| open-source-mac-os-apps | `open-source-mac-os-apps.md` | riga da aggiungere nella sezione «Audio» con una PR |

Prima dei post: registrare le GIF di ogni superficie
(`scripts/record-gif.sh`, vedi `docs/media/`).
